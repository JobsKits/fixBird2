package repository

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/ledger"
)

var (
	ErrNotFound            = errors.New("record not found")
	ErrInvalidState        = errors.New("record is in an invalid state")
	ErrAlreadyExists       = errors.New("record already exists")
	ErrIdempotencyConflict = errors.New("idempotency key was used with a different request")
	ErrRetryable           = errors.New("operation result is uncertain; retry with the same idempotency key")
	ErrWorkerNotApproved   = errors.New("worker is not approved")
)

type Repository interface {
	Ready(context.Context) error
	CreateOrder(context.Context, domain.Order, string, string) (domain.Order, bool, error)
	GetOrder(context.Context, string) (domain.Order, error)
	ListOrders(context.Context, domain.ListQuery) ([]domain.Order, error)
	SaveOrder(context.Context, domain.Order, domain.OrderStatus) error
	DemoCollect(context.Context, domain.Order, domain.Settlement) error
	ListWorkers(context.Context, int, string) ([]domain.Worker, error)
	ListSettlements(context.Context, domain.ListQuery) ([]domain.Settlement, error)
	Dashboard(context.Context) (domain.Dashboard, error)
	MarkSettlementManuallyPaid(context.Context, string) error
}

type requestRecord struct{ OrderID, Fingerprint string }

type Memory struct {
	mu                    sync.RWMutex
	orders                map[string]domain.Order
	settlements           map[string]domain.Settlement
	workers               map[string]domain.Worker
	requests              map[string]requestRecord
	enforceWorkerApproval bool
	ledger                *ledger.Memory
}

func NewMemory() *Memory {
	worker := domain.Worker{ID: "worker-demo", DisplayName: "林师傅", ServiceAreas: []string{"演示城区"}, Skills: []string{"家电维修", "水电维修", "家电清洗"}, Status: "approved"}
	return &Memory{orders: make(map[string]domain.Order), settlements: make(map[string]domain.Settlement), workers: map[string]domain.Worker{worker.ID: worker}, requests: make(map[string]requestRecord), ledger: ledger.NewMemory()}
}

func (r *Memory) Ready(ctx context.Context) error { return ctx.Err() }

func (r *Memory) CreateOrder(ctx context.Context, order domain.Order, key, fingerprint string) (domain.Order, bool, error) {
	if err := ctx.Err(); err != nil {
		return domain.Order{}, false, err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	scope := order.CustomerID + "\x00" + key
	if key != "" {
		if previous, exists := r.requests[scope]; exists {
			if previous.Fingerprint != fingerprint {
				return domain.Order{}, false, ErrIdempotencyConflict
			}
			return r.orders[previous.OrderID], true, nil
		}
	}
	if _, exists := r.orders[order.ID]; exists {
		return domain.Order{}, false, ErrAlreadyExists
	}
	r.orders[order.ID] = order
	if key != "" {
		r.requests[scope] = requestRecord{order.ID, fingerprint}
	}
	return order, false, nil
}

func (r *Memory) GetOrder(ctx context.Context, id string) (domain.Order, error) {
	if err := ctx.Err(); err != nil {
		return domain.Order{}, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	order, exists := r.orders[id]
	if !exists {
		return domain.Order{}, ErrNotFound
	}
	return order, nil
}

func (r *Memory) ListOrders(ctx context.Context, query domain.ListQuery) ([]domain.Order, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	orders := make([]domain.Order, 0)
	for _, order := range r.orders {
		if query.Actor.Role == domain.RoleWorker && order.WorkerID != query.Actor.ID {
			if query.OwnWorkerOnly {
				continue
			}
			if r.enforceWorkerApproval {
				worker, exists := r.workers[query.Actor.ID]
				if !exists || worker.Status != "approved" {
					continue
				}
			}
		}
		if domain.VisibleTo(order, query.Actor) && (query.Status == "" || order.Status == query.Status) && domain.BeforeCursor(order.CreatedAt, order.ID, query.Before) {
			orders = append(orders, order)
		}
	}
	sort.Slice(orders, func(i, j int) bool {
		if orders[i].CreatedAt.Equal(orders[j].CreatedAt) {
			return orders[i].ID > orders[j].ID
		}
		return orders[i].CreatedAt.After(orders[j].CreatedAt)
	})
	if len(orders) > query.PageSize()+1 {
		orders = orders[:query.PageSize()+1]
	}
	return orders, nil
}

func (r *Memory) SaveOrder(ctx context.Context, order domain.Order, expectedStatus domain.OrderStatus) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	current, exists := r.orders[order.ID]
	if !exists {
		return ErrNotFound
	}
	if current.Status != expectedStatus {
		return ErrInvalidState
	}
	if r.enforceWorkerApproval && expectedStatus == domain.StatusPendingWorker && order.Status == domain.StatusAccepted {
		worker, exists := r.workers[order.WorkerID]
		if !exists || worker.Status != "approved" {
			return ErrWorkerNotApproved
		}
	}
	order.UpdatedAt = time.Now().UTC().Truncate(time.Millisecond)
	r.orders[order.ID] = order
	return nil
}

func (r *Memory) DemoCollect(ctx context.Context, order domain.Order, settlement domain.Settlement) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	current, exists := r.orders[order.ID]
	if !exists {
		return ErrNotFound
	}
	if current.Status != domain.StatusAwaitingPay {
		return ErrInvalidState
	}
	for _, previous := range r.settlements {
		if previous.OrderID == order.ID {
			return ErrInvalidState
		}
	}
	order.UpdatedAt = time.Now().UTC().Truncate(time.Millisecond)
	journal, err := collectionJournal(ctx, order, settlement)
	if err != nil {
		return err
	}
	_, err = r.ledger.AppendWith(ctx, journal, func() error { r.orders[order.ID] = order; r.settlements[settlement.ID] = settlement; return nil })
	return err
}

func (r *Memory) ListWorkers(ctx context.Context, limit int, beforeID string) ([]domain.Worker, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	workers := make([]domain.Worker, 0)
	for _, worker := range r.workers {
		if beforeID == "" || worker.ID < beforeID {
			worker.ServiceAreas = append([]string(nil), worker.ServiceAreas...)
			worker.Skills = append([]string(nil), worker.Skills...)
			workers = append(workers, worker)
		}
	}
	sort.Slice(workers, func(i, j int) bool { return workers[i].ID > workers[j].ID })
	if len(workers) > limit+1 {
		workers = workers[:limit+1]
	}
	return workers, nil
}

func (r *Memory) ListSettlements(ctx context.Context, query domain.ListQuery) ([]domain.Settlement, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	settlements := make([]domain.Settlement, 0)
	for _, settlement := range r.settlements {
		if domain.BeforeCursor(settlement.CreatedAt, settlement.ID, query.Before) {
			settlements = append(settlements, settlement)
		}
	}
	sort.Slice(settlements, func(i, j int) bool {
		if settlements[i].CreatedAt.Equal(settlements[j].CreatedAt) {
			return settlements[i].ID > settlements[j].ID
		}
		return settlements[i].CreatedAt.After(settlements[j].CreatedAt)
	})
	if len(settlements) > query.PageSize()+1 {
		settlements = settlements[:query.PageSize()+1]
	}
	return settlements, nil
}

func (r *Memory) Dashboard(ctx context.Context) (domain.Dashboard, error) {
	if err := ctx.Err(); err != nil {
		return domain.Dashboard{}, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	d := domain.Dashboard{TotalOrders: len(r.orders)}
	for _, order := range r.orders {
		switch order.Status {
		case domain.StatusPendingWorker:
			d.PendingOrders++
		case domain.StatusAccepted, domain.StatusArrived, domain.StatusQuotePending, domain.StatusInService, domain.StatusAwaitingPay:
			d.ActiveOrders++
		case domain.StatusCompleted:
			d.CompletedOrders++
			var err error
			if d.GrossAmountCents, err = domain.AddCents(d.GrossAmountCents, order.QuotedAmountCents); err != nil {
				return domain.Dashboard{}, err
			}
			if d.PlatformFeeCents, err = domain.AddCents(d.PlatformFeeCents, order.PlatformFeeCents); err != nil {
				return domain.Dashboard{}, err
			}
			if d.WorkerShareCents, err = domain.AddCents(d.WorkerShareCents, order.WorkerShareCents); err != nil {
				return domain.Dashboard{}, err
			}
		}
	}
	for _, settlement := range r.settlements {
		if settlement.Status == domain.SettlementPendingManual {
			d.PendingSettlements++
		}
	}
	return d, nil
}

func (r *Memory) MarkSettlementManuallyPaid(ctx context.Context, id string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	settlement, exists := r.settlements[id]
	if !exists {
		return ErrNotFound
	}
	if settlement.Status == domain.SettlementManuallyPaid {
		return nil
	}
	if settlement.Status != domain.SettlementPendingManual {
		return ErrInvalidState
	}
	settlement.Status = domain.SettlementManuallyPaid
	order, exists := r.orders[settlement.OrderID]
	if !exists {
		return ErrNotFound
	}
	journal, err := payoutJournal(ctx, order, settlement)
	if err != nil {
		return err
	}
	_, err = r.ledger.AppendWith(ctx, journal, func() error { r.settlements[id] = settlement; return nil })
	return err
}
