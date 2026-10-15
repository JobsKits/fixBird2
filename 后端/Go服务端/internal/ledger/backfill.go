package ledger

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

type legacyRecord struct {
	Collection
	PaymentID, Provider, PaymentStatus, SettlementStatus string
	PaidAt                                               time.Time
}

// Adopt old simulated receipts without changing old SQL files or overwriting their business records.
// Unexpected/missing payment provenance fails the transaction instead of inventing actual receipts.
func (store *TiDB) BackfillTx(ctx context.Context, tx *sql.Tx) error {
	var missingSettlement int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM repair_payments p LEFT JOIN repair_settlements s ON s.order_id=p.order_id
 WHERE p.provider='manual_demo' AND p.status='demo_paid' AND s.id IS NULL`).Scan(&missingSettlement); err != nil {
		return err
	}
	if missingSettlement != 0 {
		return fmt.Errorf("%w: legacy simulated payments have no settlement; preserve and review them", ErrInvalidState)
	}
	rows, err := tx.QueryContext(ctx, `SELECT s.id,s.order_id,o.customer_id,s.worker_id,s.gross_amount_cents,s.worker_share_cents,s.platform_fee_cents,
 s.status,s.created_at,s.updated_at,p.id,p.provider,p.status,p.amount_cents
 FROM repair_settlements s LEFT JOIN repair_orders o ON o.id=s.order_id
 LEFT JOIN repair_payments p ON p.order_id=s.order_id AND p.provider='manual_demo' AND p.status='demo_paid' ORDER BY s.created_at,s.id,p.created_at`)
	if err != nil {
		return err
	}
	records := make([]legacyRecord, 0)
	for rows.Next() {
		var record legacyRecord
		var paymentID, provider, paymentStatus sql.NullString
		var paymentAmount sql.NullInt64
		if err := rows.Scan(&record.SettlementID, &record.OrderID, &record.CustomerID, &record.WorkerID, &record.AmountCents, &record.WorkerShareCents, &record.PlatformFeeCents,
			&record.SettlementStatus, &record.OccurredAt, &record.PaidAt, &paymentID, &provider, &paymentStatus, &paymentAmount); err != nil {
			_ = rows.Close()
			return err
		}
		if !paymentID.Valid || provider.String != "manual_demo" || paymentStatus.String != "demo_paid" || paymentAmount.Int64 != record.AmountCents ||
			(record.SettlementStatus != "pending_manual" && record.SettlementStatus != "manually_paid") {
			_ = rows.Close()
			return fmt.Errorf("%w: legacy settlement %s has unsupported payment provenance; preserve and review it", ErrInvalidState, record.SettlementID)
		}
		record.PaymentID, record.Provider, record.PaymentStatus = paymentID.String, provider.String, paymentStatus.String
		record.Mode, record.Channel, record.ActorID, record.Reason = ModeSimulated, ChannelDemo, "system", "legacy simulated receipt adopted: "+paymentID.String
		records = append(records, record)
		if len(records) > MaxExportJournals {
			_ = rows.Close()
			return fmt.Errorf("%w: legacy adoption requires a separate batch migration", ErrExportTooLarge)
		}
	}
	readError := rows.Err()
	if err := rows.Close(); err != nil {
		return err
	}
	if readError != nil {
		return readError
	}
	for _, record := range records {
		journal, err := NewCollection(record.Collection)
		if err != nil {
			return err
		}
		if _, err := store.AppendTx(ctx, tx, journal); err != nil {
			return err
		}
		if record.SettlementStatus == "manually_paid" {
			payout, err := NewPayout(Payout{OrderID: record.OrderID, CustomerID: record.CustomerID, WorkerID: record.WorkerID, SettlementID: record.SettlementID,
				Mode: ModeSimulated, Channel: ChannelManual, ActorID: "system", Reason: "legacy manual attestation adopted; simulated, no bank transfer", AmountCents: record.WorkerShareCents, OccurredAt: record.PaidAt})
			if err != nil {
				return err
			}
			if _, err := store.AppendTx(ctx, tx, payout); err != nil {
				return err
			}
		}
	}
	return nil
}

func (store *TiDB) Backfill(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	tx, err := store.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := store.BackfillTx(ctx, tx); err != nil {
		return err
	}
	return tx.Commit()
}
