package ledger

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

type TiDB struct{ db *sql.DB }

func NewTiDB(db *sql.DB) *TiDB { return &TiDB{db: db} }

type sqlReader interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	QueryRowContext(context.Context, string, ...any) *sql.Row
}
type rowScanner interface{ Scan(...any) error }

const journalColumns = `j.id, j.event_key, j.fingerprint, j.order_id, j.customer_id, j.worker_id, j.settlement_id,
 j.mode, j.simulated, j.kind, j.channel, j.amount_cents, j.worker_share_cents, j.platform_fee_cents,
 j.actor_id, j.reason, COALESCE(j.reversal_of_id, ''), j.occurred_at, j.created_at,
 CASE WHEN EXISTS (SELECT 1 FROM repair_ledger_journals correction WHERE correction.reversal_of_id = j.id) THEN 'reversed' ELSE 'posted' END`

func (store *TiDB) Ready(ctx context.Context) error {
	if err := store.db.PingContext(ctx); err != nil {
		return err
	}
	for _, statement := range []string{
		"SELECT " + journalColumns + " FROM repair_ledger_journals j LIMIT 0",
		"SELECT journal_id, line_number, account, direction, amount_cents FROM repair_ledger_entries LIMIT 0",
	} {
		rows, err := store.db.QueryContext(ctx, statement)
		if err != nil {
			return err
		}
		if err := rows.Close(); err != nil {
			return err
		}
	}
	var ready int
	if err := store.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_schema_migrations WHERE version = '005_ledger.sql' AND dirty = FALSE").Scan(&ready); err != nil {
		return err
	}
	if ready != 1 {
		return ErrInvalidState
	}
	return nil
}

func scanJournal(row rowScanner) (Journal, error) {
	var journal Journal
	err := row.Scan(&journal.ID, &journal.EventKey, &journal.Fingerprint, &journal.OrderID, &journal.CustomerID, &journal.WorkerID, &journal.SettlementID,
		&journal.Mode, &journal.Simulated, &journal.Kind, &journal.Channel, &journal.AmountCents, &journal.WorkerShareCents, &journal.PlatformFeeCents,
		&journal.ActorID, &journal.Reason, &journal.ReversalOfID, &journal.OccurredAt, &journal.CreatedAt, &journal.Status)
	if errors.Is(err, sql.ErrNoRows) {
		return Journal{}, ErrNotFound
	}
	journal.OccurredAt, journal.CreatedAt = journal.OccurredAt.UTC(), journal.CreatedAt.UTC()
	return journal, err
}

func readEntries(ctx context.Context, reader sqlReader, journals []Journal) error {
	if len(journals) == 0 {
		return nil
	}
	args, index := make([]any, len(journals)), make(map[string]int, len(journals))
	for position := range journals {
		args[position], index[journals[position].ID] = journals[position].ID, position
		journals[position].Entries = []Entry{}
	}
	holders := strings.TrimRight(strings.Repeat("?,", len(args)), ",")
	rows, err := reader.QueryContext(ctx, "SELECT journal_id, account, direction, amount_cents FROM repair_ledger_entries WHERE journal_id IN ("+holders+") ORDER BY journal_id, line_number", args...)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var entry Entry
		if err := rows.Scan(&id, &entry.Account, &entry.Direction, &entry.AmountCents); err != nil {
			return err
		}
		if position, exists := index[id]; exists {
			journals[position].Entries = append(journals[position].Entries, entry)
		}
	}
	return rows.Err()
}

func readJournal(ctx context.Context, reader sqlReader, condition string, arg any, lock bool) (Journal, error) {
	statement := "SELECT " + journalColumns + " FROM repair_ledger_journals j WHERE " + condition
	if lock {
		statement += " FOR UPDATE"
	}
	journal, err := scanJournal(reader.QueryRowContext(ctx, statement, arg))
	if err != nil {
		return Journal{}, err
	}
	items := []Journal{journal}
	if err := readEntries(ctx, reader, items); err != nil {
		return Journal{}, err
	}
	return items[0], nil
}

func (store *TiDB) Get(ctx context.Context, id string) (Journal, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	return readJournal(ctx, store.db, "j.id = ?", id, false)
}
func (store *TiDB) GetEvent(ctx context.Context, key string) (Journal, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	return readJournal(ctx, store.db, "j.event_key = ?", key, false)
}

// AppendTx never commits independently: business payment/settlement and journal must commit together.
func (store *TiDB) AppendTx(ctx context.Context, tx *sql.Tx, journal Journal) (Journal, error) {
	if err := ValidateJournal(journal); err != nil {
		return Journal{}, err
	}
	previous, err := readJournal(ctx, tx, "j.event_key = ?", journal.EventKey, true)
	if err == nil {
		if !sameFinancialEvent(previous, journal) {
			return Journal{}, ErrIdempotencyConflict
		}
		return previous, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return Journal{}, err
	}
	byEvent, byID, reversed := map[string]Journal{}, map[string]Journal{}, map[string]string{}
	remember := func(value Journal) {
		byEvent[value.EventKey], byID[value.ID] = value, value
		if value.Status == StatusReversed {
			reversed[value.ID] = "already-reversed"
		}
	}
	if journal.Kind == KindPayout {
		collection, err := readJournal(ctx, tx, "j.event_key = ?", CollectionEventKey(journal.Mode, journal.OrderID), true)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				return Journal{}, ErrInvalidState
			}
			return Journal{}, err
		}
		remember(collection)
	} else if journal.Kind == KindReversal {
		original, err := readJournal(ctx, tx, "j.id = ?", journal.ReversalOfID, true)
		if err != nil {
			return Journal{}, err
		}
		remember(original)
		if original.Kind == KindCollection {
			payout, err := readJournal(ctx, tx, "j.event_key = ?", PayoutEventKey(original.Mode, original.SettlementID), true)
			if err == nil {
				remember(payout)
			} else if !errors.Is(err, ErrNotFound) {
				return Journal{}, err
			}
		}
	}
	if err := validateAgainstState(journal, byEvent, byID, reversed); err != nil {
		return Journal{}, err
	}
	var originalID any
	if journal.ReversalOfID != "" {
		originalID = journal.ReversalOfID
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO repair_ledger_journals
 (id,event_key,fingerprint,order_id,customer_id,worker_id,settlement_id,mode,simulated,kind,channel,
 amount_cents,worker_share_cents,platform_fee_cents,actor_id,reason,reversal_of_id,occurred_at,created_at)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, journal.ID, journal.EventKey, journal.Fingerprint, journal.OrderID, journal.CustomerID, journal.WorkerID,
		journal.SettlementID, journal.Mode, journal.Simulated, journal.Kind, journal.Channel, journal.AmountCents, journal.WorkerShareCents,
		journal.PlatformFeeCents, journal.ActorID, journal.Reason, originalID, journal.OccurredAt, journal.CreatedAt)
	if err != nil {
		return Journal{}, transactionError(err)
	}
	for position, entry := range journal.Entries {
		if _, err := tx.ExecContext(ctx, "INSERT INTO repair_ledger_entries (journal_id,line_number,account,direction,amount_cents) VALUES (?,?,?,?,?)",
			journal.ID, position+1, entry.Account, entry.Direction, entry.AmountCents); err != nil {
			return Journal{}, transactionError(err)
		}
	}
	return clone(journal), nil
}

func transactionError(err error) error {
	var driverError *mysql.MySQLError
	if errors.As(err, &driverError) && (driverError.Number == 1062 || driverError.Number == 9007 || driverError.Number == 1213 || driverError.Number == 1205) {
		return ErrUncertain
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return ErrUncertain
	}
	return err
}

func (store *TiDB) Append(ctx context.Context, journal Journal) (Journal, error) {
	parent := ctx
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	for attempt := 0; attempt < 3; attempt++ {
		tx, err := store.db.BeginTx(ctx, nil)
		if err != nil {
			return Journal{}, err
		}
		saved, err := store.AppendTx(ctx, tx, journal)
		if err != nil {
			_ = tx.Rollback()
			if errors.Is(err, ErrUncertain) && ctx.Err() == nil {
				continue
			}
			return Journal{}, err
		}
		if err := tx.Commit(); err == nil {
			return saved, nil
		}
		resolved, err := store.GetEvent(parent, journal.EventKey)
		if err == nil {
			if !sameFinancialEvent(resolved, journal) {
				return Journal{}, ErrIdempotencyConflict
			}
			return resolved, nil
		}
		if ctx.Err() != nil {
			return Journal{}, ErrUncertain
		}
	}
	return Journal{}, ErrUncertain
}

func sqlFilter(query Query) (string, []any) {
	conditions, args := []string{"j.mode = ?"}, []any{query.Mode}
	for _, field := range []struct{ column, value string }{{"j.kind", query.Kind}, {"j.channel", query.Channel}, {"j.order_id", query.OrderID}, {"j.customer_id", query.CustomerID}, {"j.worker_id", query.WorkerID}} {
		if field.value != "" {
			conditions, args = append(conditions, field.column+" = ?"), append(args, field.value)
		}
	}
	if query.Status != "" {
		condition := "EXISTS (SELECT 1 FROM repair_ledger_journals correction WHERE correction.reversal_of_id = j.id)"
		if query.Status == StatusPosted {
			condition = "NOT " + condition
		}
		conditions = append(conditions, condition)
	}
	if !query.From.IsZero() {
		conditions, args = append(conditions, "j.occurred_at >= ?"), append(args, query.From.UTC())
	}
	if !query.To.IsZero() {
		conditions, args = append(conditions, "j.occurred_at < ?"), append(args, query.To.UTC())
	}
	if query.Before != nil {
		conditions = append(conditions, "(j.occurred_at < ? OR (j.occurred_at = ? AND j.id < ?))")
		args = append(args, query.Before.OccurredAt.UTC(), query.Before.OccurredAt.UTC(), query.Before.ID)
	}
	return strings.Join(conditions, " AND "), args
}

func (store *TiDB) List(ctx context.Context, query Query) ([]Journal, error) {
	query, err := NormalizeQuery(query)
	if err != nil {
		return nil, err
	}
	return store.Snapshot(ctx, query, query.Limit+1)
}

func (store *TiDB) Snapshot(ctx context.Context, query Query, max int) ([]Journal, error) {
	query, err := NormalizeQuery(query)
	if err != nil || max < 1 || max > MaxExportJournals+1 {
		return nil, ErrInvalidInput
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	condition, args := sqlFilter(query)
	args = append(args, max)
	rows, err := store.db.QueryContext(ctx, "SELECT "+journalColumns+" FROM repair_ledger_journals j WHERE "+condition+" ORDER BY j.occurred_at DESC,j.id DESC LIMIT ?", args...)
	if err != nil {
		return nil, err
	}
	items := make([]Journal, 0)
	for rows.Next() {
		journal, err := scanJournal(rows)
		if err != nil {
			_ = rows.Close()
			return nil, err
		}
		items = append(items, journal)
	}
	readError := rows.Err()
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if readError != nil {
		return nil, readError
	}
	if err := readEntries(ctx, store.db, items); err != nil {
		return nil, err
	}
	return items, nil
}

// SQL aggregates journals separately from entries to avoid tripling gross amounts in a join.
func (store *TiDB) Summary(ctx context.Context, query Query) (Summary, error) {
	query, err := NormalizeQuery(query)
	if err != nil {
		return Summary{}, err
	}
	query.Before = nil
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	condition, args := sqlFilter(query)
	summary := newSummary(query.Mode)
	statement := `SELECT COUNT(*),
 COALESCE(SUM(CASE WHEN j.kind='collection' THEN j.amount_cents WHEN j.kind='reversal' AND original.kind='collection' THEN -j.amount_cents ELSE 0 END),0),
 COALESCE(SUM(CASE WHEN j.kind='collection' THEN j.worker_share_cents WHEN j.kind='reversal' AND original.kind='collection' THEN -j.worker_share_cents ELSE 0 END),0),
 COALESCE(SUM(CASE WHEN j.kind='collection' THEN j.platform_fee_cents WHEN j.kind='reversal' AND original.kind='collection' THEN -j.platform_fee_cents ELSE 0 END),0),
 COALESCE(SUM(CASE WHEN j.kind='manual_payout' THEN j.amount_cents WHEN j.kind='reversal' AND original.kind='manual_payout' THEN -j.amount_cents ELSE 0 END),0)
 FROM repair_ledger_journals j LEFT JOIN repair_ledger_journals original ON original.id=j.reversal_of_id WHERE ` + condition
	if err := store.db.QueryRowContext(ctx, statement, args...).Scan(&summary.JournalCount, &summary.CollectedCents, &summary.WorkerAccruedCents, &summary.PlatformRevenueCents, &summary.PayoutCents); err != nil {
		return Summary{}, err
	}
	// Balanced journals make these identities exact; checked subtraction rejects any integer overflow.
	if summary.PlatformFundsCents, err = subtractCents(summary.CollectedCents, summary.PayoutCents); err != nil {
		return Summary{}, err
	}
	if summary.WorkerPayableCents, err = subtractCents(summary.WorkerAccruedCents, summary.PayoutCents); err != nil {
		return Summary{}, err
	}
	return summary, nil
}
