package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"

	"repair-platform/internal/domain"
	"repair-platform/internal/ledger"
)

type TiDB struct {
	db                    *sql.DB
	enforceWorkerApproval bool
	ledger                *ledger.TiDB
}

func OpenTiDB(ctx context.Context, dsn string) (*TiDB, error) {
	driverConfig, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, err
	}
	driverConfig.ParseTime = true
	if driverConfig.Timeout == 0 {
		driverConfig.Timeout = 5 * time.Second
	}
	if driverConfig.ReadTimeout == 0 {
		driverConfig.ReadTimeout = 5 * time.Second
	}
	if driverConfig.WriteTimeout == 0 {
		driverConfig.WriteTimeout = 5 * time.Second
	}
	if driverConfig.Loc == nil {
		driverConfig.Loc = time.UTC
	}

	db, err := sql.Open("mysql", driverConfig.FormatDSN())
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &TiDB{db: db, ledger: ledger.NewTiDB(db)}, nil
}

func (r *TiDB) Close() error {
	return r.db.Close()
}

func (r *TiDB) DB() *sql.DB { return r.db }

func (r *TiDB) Ready(ctx context.Context) error {
	if err := r.db.PingContext(ctx); err != nil {
		return err
	}
	for _, statement := range []string{
		"SELECT " + orderColumns + " FROM repair_orders LIMIT 0",
		"SELECT id, display_name, service_areas, skills, status FROM repair_workers LIMIT 0",
		"SELECT id, order_id, provider, amount_cents, status, created_at FROM repair_payments LIMIT 0",
		"SELECT id, order_id, worker_id, gross_amount_cents, platform_fee_cents, worker_share_cents, status, profit_rule_version, created_at FROM repair_settlements LIMIT 0",
		"SELECT actor_id, idempotency_key, request_hash, order_id FROM repair_order_requests LIMIT 0",
	} {
		rows, err := r.db.QueryContext(ctx, statement)
		if err != nil {
			return err
		}
		if err := rows.Close(); err != nil {
			return err
		}
	}
	var count int
	if err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_schema_migrations WHERE version IN ('001_init.sql', '002_order_requests.sql', '003_profit_rule.sql', '004_identity_workers_assets.sql') AND dirty = FALSE").Scan(&count); err != nil {
		return err
	}
	if count != 4 {
		return errors.New("required schema migrations are not ready")
	}
	if err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_schema_migrations WHERE dirty = TRUE").Scan(&count); err != nil {
		return err
	}
	if count != 0 {
		return errors.New("schema has an incomplete migration")
	}
	return nil
}

func (r *TiDB) Exec(ctx context.Context, statement string) error {
	_, err := r.db.ExecContext(ctx, statement)
	return err
}

func (r *TiDB) CreateOrder(ctx context.Context, order domain.Order, key, fingerprint string) (domain.Order, bool, error) {
	parentContext := ctx
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.Order{}, false, err
	}
	defer tx.Rollback()
	if key != "" {
		_, err = tx.ExecContext(ctx, "INSERT INTO repair_order_requests (actor_id, idempotency_key, request_hash, order_id) VALUES (?, ?, ?, ?)", order.CustomerID, key, fingerprint, order.ID)
		if err != nil {
			_ = tx.Rollback()
			var driverError *mysql.MySQLError
			if errors.As(err, &driverError) && driverError.Number == 1062 {
				previous, err := r.resolveRequest(parentContext, order.CustomerID, key, fingerprint)
				return previous, true, err
			}
			if retryableTransaction(err) {
				return domain.Order{}, false, ErrRetryable
			}
			return domain.Order{}, false, err
		}
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO repair_orders (
			id, customer_id, worker_id, category, equipment, issue, address,
			scheduled_at, status, payment_status, quoted_amount_cents,
			platform_fee_cents, worker_share_cents, profit_rule_version, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		order.ID,
		order.CustomerID,
		order.WorkerID,
		order.Category,
		order.Equipment,
		order.Issue,
		order.Address,
		order.ScheduledAt,
		order.Status,
		order.PaymentStatus,
		order.QuotedAmountCents,
		order.PlatformFeeCents,
		order.WorkerShareCents,
		order.ProfitRuleVersion,
		order.CreatedAt,
		order.UpdatedAt,
	)
	if err != nil {
		return domain.Order{}, false, err
	}
	if err := tx.Commit(); err != nil {
		if key != "" {
			previous, resolveErr := r.resolveRequest(parentContext, order.CustomerID, key, fingerprint)
			if resolveErr == nil || errors.Is(resolveErr, ErrIdempotencyConflict) {
				return previous, true, resolveErr
			}
			return domain.Order{}, false, ErrRetryable
		}
		if retryableTransaction(err) {
			return domain.Order{}, false, ErrRetryable
		}
		return domain.Order{}, false, err
	}
	return order, false, nil
}

func retryableTransaction(err error) bool {
	var driverError *mysql.MySQLError
	if errors.As(err, &driverError) {
		return driverError.Number == 1062 || driverError.Number == 9007 || driverError.Number == 1213 || driverError.Number == 1205 || driverError.Number == 8028
	}
	return errors.Is(err, context.DeadlineExceeded)
}

func (r *TiDB) resolveRequest(ctx context.Context, actorID, key, fingerprint string) (domain.Order, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	var previousHash, orderID string
	if err := r.db.QueryRowContext(ctx, "SELECT request_hash, order_id FROM repair_order_requests WHERE actor_id = ? AND idempotency_key = ?", actorID, key).Scan(&previousHash, &orderID); err != nil {
		return domain.Order{}, err
	}
	if previousHash != fingerprint {
		return domain.Order{}, ErrIdempotencyConflict
	}
	return r.GetOrder(ctx, orderID)
}

func (r *TiDB) GetOrder(ctx context.Context, id string) (domain.Order, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	row := r.db.QueryRowContext(ctx, "SELECT "+orderColumns+" FROM repair_orders WHERE id = ?", id)
	order, err := scanOrder(row)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Order{}, ErrNotFound
	}
	return order, err
}

func (r *TiDB) ListOrders(ctx context.Context, query domain.ListQuery) ([]domain.Order, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	conditions, args := []string{"1 = 1"}, []any{}
	switch query.Actor.Role {
	case domain.RoleCustomer:
		conditions, args = append(conditions, "customer_id = ?"), append(args, query.Actor.ID)
	case domain.RoleWorker:
		if query.Actor.Demo {
			conditions, args = append(conditions, "customer_id = ?"), append(args, "customer-demo")
		}
		if query.OwnWorkerOnly {
			conditions, args = append(conditions, "worker_id = ?"), append(args, query.Actor.ID)
		} else if r.enforceWorkerApproval {
			conditions, args = append(conditions, "((status = ? AND EXISTS (SELECT 1 FROM repair_workers qualification WHERE qualification.id = ? AND qualification.status = 'approved')) OR worker_id = ?)"), append(args, domain.StatusPendingWorker, query.Actor.ID, query.Actor.ID)
		} else {
			conditions, args = append(conditions, "(status = ? OR worker_id = ?)"), append(args, domain.StatusPendingWorker, query.Actor.ID)
		}
	case domain.RoleAdmin:
	default:
		conditions = append(conditions, "1 = 0")
	}
	if query.Status != "" {
		conditions, args = append(conditions, "status = ?"), append(args, query.Status)
	}
	if query.Before != nil {
		conditions = append(conditions, "(created_at < ? OR (created_at = ? AND id < ?))")
		args = append(args, query.Before.CreatedAt, query.Before.CreatedAt, query.Before.ID)
	}
	args = append(args, query.PageSize()+1)
	rows, err := r.db.QueryContext(ctx, "SELECT "+orderColumns+" FROM repair_orders WHERE "+strings.Join(conditions, " AND ")+" ORDER BY created_at DESC, id DESC LIMIT ?", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	orders := make([]domain.Order, 0)
	for rows.Next() {
		order, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		orders = append(orders, order)
	}
	return orders, rows.Err()
}

func (r *TiDB) SaveOrder(ctx context.Context, order domain.Order, expectedStatus domain.OrderStatus) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var exec interface {
		ExecContext(context.Context, string, ...any) (sql.Result, error)
	} = r.db
	var transaction *sql.Tx
	if r.enforceWorkerApproval && expectedStatus == domain.StatusPendingWorker && order.Status == domain.StatusAccepted {
		var err error
		transaction, err = r.db.BeginTx(ctx, nil)
		if err != nil {
			return err
		}
		defer transaction.Rollback()
		var status string
		if err := transaction.QueryRowContext(ctx, "SELECT status FROM repair_workers WHERE id=? FOR UPDATE", order.WorkerID).Scan(&status); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return ErrWorkerNotApproved
			}
			return err
		}
		if status != "approved" {
			return ErrWorkerNotApproved
		}
		// The row write makes approval changes participate in optimistic conflict detection too.
		if _, err := transaction.ExecContext(ctx, "UPDATE repair_workers SET qualification_version=qualification_version+1 WHERE id=?", order.WorkerID); err != nil {
			return err
		}
		exec = transaction
	}
	result, err := exec.ExecContext(ctx, `
		UPDATE repair_orders
		SET worker_id = ?, status = ?, payment_status = ?, quoted_amount_cents = ?,
			platform_fee_cents = ?, worker_share_cents = ?, updated_at = ?
		WHERE id = ? AND status = ?`,
		order.WorkerID,
		order.Status,
		order.PaymentStatus,
		order.QuotedAmountCents,
		order.PlatformFeeCents,
		order.WorkerShareCents,
		time.Now().UTC(),
		order.ID,
		expectedStatus,
	)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return ErrInvalidState
	}
	if transaction != nil {
		return transaction.Commit()
	}
	return nil
}

func (r *TiDB) DemoCollect(ctx context.Context, order domain.Order, settlement domain.Settlement) error {
	parentContext := ctx
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var status domain.OrderStatus
	if err := tx.QueryRowContext(ctx,
		"SELECT status FROM repair_orders WHERE id = ? FOR UPDATE",
		order.ID,
	).Scan(&status); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		_ = tx.Rollback()
		return r.collectTransactionError(parentContext, order.ID, err)
	}
	if status != domain.StatusAwaitingPay {
		return ErrInvalidState
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE repair_orders
		SET status = ?, payment_status = ?, platform_fee_cents = ?,
			worker_share_cents = ?, profit_rule_version = ?, updated_at = ?
		WHERE id = ?`,
		order.Status,
		order.PaymentStatus,
		order.PlatformFeeCents,
		order.WorkerShareCents,
		order.ProfitRuleVersion,
		time.Now().UTC(),
		order.ID,
	); err != nil {
		_ = tx.Rollback()
		return r.collectTransactionError(parentContext, order.ID, err)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO repair_payments (id, order_id, provider, amount_cents, status)
		VALUES (?, ?, ?, ?, ?)`,
		settlement.ID+"_payment",
		order.ID,
		"manual_demo",
		settlement.GrossAmountCents,
		"demo_paid",
	); err != nil {
		_ = tx.Rollback()
		return r.collectTransactionError(parentContext, order.ID, err)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO repair_settlements (
			id, order_id, worker_id, gross_amount_cents, platform_fee_cents,
			worker_share_cents, status, profit_rule_version, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		settlement.ID,
		settlement.OrderID,
		settlement.WorkerID,
		settlement.GrossAmountCents,
		settlement.PlatformFeeCents,
		settlement.WorkerShareCents,
		settlement.Status,
		settlement.ProfitRuleVersion,
		settlement.CreatedAt,
	); err != nil {
		_ = tx.Rollback()
		return r.collectTransactionError(parentContext, order.ID, err)
	}
	journal, err := collectionJournal(ctx, order, settlement)
	if err != nil {
		return err
	}
	if _, err := r.ledger.AppendTx(ctx, tx, journal); err != nil {
		_ = tx.Rollback()
		return r.collectTransactionError(parentContext, order.ID, err)
	}
	if err := tx.Commit(); err != nil {
		return r.collectTransactionError(parentContext, order.ID, err)
	}
	return nil
}

func (r *TiDB) collectTransactionError(ctx context.Context, orderID string, original error) error {
	if !retryableTransaction(original) {
		return original
	}
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	for {
		order, err := r.GetOrder(ctx, orderID)
		if err == nil {
			if order.Status == domain.StatusCompleted && order.PaymentStatus == domain.PaymentDemoPaid {
				return ErrInvalidState
			}
			if order.Status != domain.StatusAwaitingPay {
				return ErrRetryable
			}
		} else if errors.Is(err, ErrNotFound) {
			return ErrRetryable
		}
		// A conflicting transaction may still be committing; only observe its result, never repeat this write.
		timer := time.NewTimer(20 * time.Millisecond)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ErrRetryable
		case <-timer.C:
		}
	}
}

func (r *TiDB) ListWorkers(ctx context.Context, limit int, beforeID string) ([]domain.Worker, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	statement := "SELECT id, display_name, service_areas, skills, status FROM repair_workers"
	args := []any{}
	if beforeID != "" {
		statement += " WHERE id < ?"
		args = append(args, beforeID)
	}
	args = append(args, limit+1)
	rows, err := r.db.QueryContext(ctx, statement+" ORDER BY id DESC LIMIT ?", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	workers := make([]domain.Worker, 0)
	for rows.Next() {
		var worker domain.Worker
		var serviceAreas []byte
		var skills []byte
		if err := rows.Scan(
			&worker.ID,
			&worker.DisplayName,
			&serviceAreas,
			&skills,
			&worker.Status,
		); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(serviceAreas, &worker.ServiceAreas); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(skills, &worker.Skills); err != nil {
			return nil, err
		}
		workers = append(workers, worker)
	}
	return workers, rows.Err()
}

func (r *TiDB) ListSettlements(ctx context.Context, query domain.ListQuery) ([]domain.Settlement, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	statement := "SELECT id, order_id, worker_id, gross_amount_cents, platform_fee_cents, worker_share_cents, status, profit_rule_version, created_at FROM repair_settlements"
	args := []any{}
	if query.Before != nil {
		statement += " WHERE (created_at < ? OR (created_at = ? AND id < ?))"
		args = append(args, query.Before.CreatedAt, query.Before.CreatedAt, query.Before.ID)
	}
	args = append(args, query.PageSize()+1)
	rows, err := r.db.QueryContext(ctx, statement+" ORDER BY created_at DESC, id DESC LIMIT ?", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	settlements := make([]domain.Settlement, 0)
	for rows.Next() {
		var settlement domain.Settlement
		if err := rows.Scan(
			&settlement.ID,
			&settlement.OrderID,
			&settlement.WorkerID,
			&settlement.GrossAmountCents,
			&settlement.PlatformFeeCents,
			&settlement.WorkerShareCents,
			&settlement.Status,
			&settlement.ProfitRuleVersion,
			&settlement.CreatedAt,
		); err != nil {
			return nil, err
		}
		settlements = append(settlements, settlement)
	}
	return settlements, rows.Err()
}

func (r *TiDB) MarkSettlementManuallyPaid(ctx context.Context, id string) error {
	return r.markPaidLedger(ctx, id)
}

const orderColumns = `
	id, customer_id, worker_id, category, equipment, issue, address,
	scheduled_at, status, payment_status, quoted_amount_cents,
	platform_fee_cents, worker_share_cents, profit_rule_version, created_at, updated_at
`

type rowScanner interface {
	Scan(...any) error
}

func scanOrder(row rowScanner) (domain.Order, error) {
	var order domain.Order
	err := row.Scan(
		&order.ID,
		&order.CustomerID,
		&order.WorkerID,
		&order.Category,
		&order.Equipment,
		&order.Issue,
		&order.Address,
		&order.ScheduledAt,
		&order.Status,
		&order.PaymentStatus,
		&order.QuotedAmountCents,
		&order.PlatformFeeCents,
		&order.WorkerShareCents,
		&order.ProfitRuleVersion,
		&order.CreatedAt,
		&order.UpdatedAt,
	)
	return order, err
}

func requireAffected(result sql.Result) error {
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return ErrNotFound
	}
	return nil
}
