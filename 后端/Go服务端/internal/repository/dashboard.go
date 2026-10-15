package repository

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"repair-platform/internal/domain"
)

func (r *TiDB) Dashboard(ctx context.Context) (domain.Dashboard, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var d domain.Dashboard
	var gross, fee, share string
	err := r.db.QueryRowContext(ctx, `SELECT
		COUNT(*), COALESCE(SUM(status = 'pending_worker'), 0),
		COALESCE(SUM(status IN ('accepted','arrived','quote_pending','in_service','awaiting_payment')), 0),
		COALESCE(SUM(status = 'completed'), 0),
		(SELECT COUNT(*) FROM repair_settlements WHERE status = 'pending_manual'),
		COALESCE(SUM(CASE WHEN status = 'completed' THEN quoted_amount_cents ELSE 0 END), 0),
		COALESCE(SUM(CASE WHEN status = 'completed' THEN platform_fee_cents ELSE 0 END), 0),
		COALESCE(SUM(CASE WHEN status = 'completed' THEN worker_share_cents ELSE 0 END), 0)
		FROM repair_orders`).Scan(&d.TotalOrders, &d.PendingOrders, &d.ActiveOrders, &d.CompletedOrders, &d.PendingSettlements, &gross, &fee, &share)
	if err != nil {
		return domain.Dashboard{}, err
	}
	for _, amount := range []struct {
		value  string
		target *int64
	}{{gross, &d.GrossAmountCents}, {fee, &d.PlatformFeeCents}, {share, &d.WorkerShareCents}} {
		value, err := strconv.ParseInt(amount.value, 10, 64)
		if err != nil || value < 0 {
			return domain.Dashboard{}, fmt.Errorf("%w: dashboard total", domain.ErrAmountOverflow)
		}
		*amount.target = value
	}
	return d, nil
}
