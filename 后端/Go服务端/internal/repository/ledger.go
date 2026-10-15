package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/ledger"
)

func (r *Memory) LedgerStore() ledger.Store { return r.ledger }
func (r *TiDB) LedgerStore() ledger.Store   { return r.ledger }

func collectionJournal(ctx context.Context, order domain.Order, settlement domain.Settlement) (ledger.Journal, error) {
	return ledger.NewCollection(ledger.Collection{OrderID: order.ID, CustomerID: order.CustomerID, WorkerID: order.WorkerID, SettlementID: settlement.ID, ActorID: domain.AuditActorID(ctx), AmountCents: settlement.GrossAmountCents, WorkerShareCents: settlement.WorkerShareCents, PlatformFeeCents: settlement.PlatformFeeCents, OccurredAt: settlement.CreatedAt})
}
func payoutJournal(ctx context.Context, order domain.Order, settlement domain.Settlement) (ledger.Journal, error) {
	return ledger.NewPayout(ledger.Payout{OrderID: order.ID, CustomerID: order.CustomerID, WorkerID: settlement.WorkerID, SettlementID: settlement.ID, ActorID: domain.AuditActorID(ctx), AmountCents: settlement.WorkerShareCents, OccurredAt: time.Now().UTC().Truncate(time.Millisecond)})
}

func (r *TiDB) markPaidLedger(ctx context.Context, id string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var settlement domain.Settlement
	var customerID string
	err = tx.QueryRowContext(ctx, "SELECT s.id, s.order_id, s.worker_id, s.gross_amount_cents, s.platform_fee_cents, s.worker_share_cents, s.status, o.customer_id FROM repair_settlements s JOIN repair_orders o ON o.id=s.order_id WHERE s.id=? FOR UPDATE", id).Scan(&settlement.ID, &settlement.OrderID, &settlement.WorkerID, &settlement.GrossAmountCents, &settlement.PlatformFeeCents, &settlement.WorkerShareCents, &settlement.Status, &customerID)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if settlement.Status != domain.SettlementPendingManual && settlement.Status != domain.SettlementManuallyPaid {
		return ErrInvalidState
	}
	journal, err := payoutJournal(ctx, domain.Order{ID: settlement.OrderID, CustomerID: customerID}, settlement)
	if err != nil {
		return err
	}
	if _, err := r.ledger.AppendTx(ctx, tx, journal); err != nil {
		return err
	}
	if settlement.Status == domain.SettlementPendingManual {
		if _, err := tx.ExecContext(ctx, "UPDATE repair_settlements SET status=? WHERE id=?", domain.SettlementManuallyPaid, id); err != nil {
			return err
		}
	}
	return tx.Commit()
}
