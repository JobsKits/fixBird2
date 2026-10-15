package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/payment"
	"repair-platform/internal/repository"
)

var (
	ErrForbidden         = errors.New("action is not allowed for this role")
	ErrInvalidInput      = errors.New("required order information is missing")
	ErrPaymentPending    = errors.New("payment provider is not configured")
	ErrWorkerNotApproved = errors.New("worker application must be approved")
)

type Marketplace struct {
	repository repository.Repository
	demoMode   bool
	gateways   map[payment.Provider]payment.Gateway
	workerGate interface {
		CanAccept(context.Context, string) (bool, error)
	}
}

func (s *Marketplace) SetWorkerGate(gate interface {
	CanAccept(context.Context, string) (bool, error)
}) {
	s.workerGate = gate
}

func (s *Marketplace) requireApprovedWorker(ctx context.Context, actor domain.Actor) error {
	if s.workerGate == nil || actor.Role != domain.RoleWorker {
		return nil
	}
	approved, err := s.workerGate.CanAccept(ctx, actor.ID)
	if err != nil {
		return err
	}
	if !approved {
		return ErrWorkerNotApproved
	}
	return nil
}

func NewMarketplace(repo repository.Repository, demoMode bool) *Marketplace {
	return &Marketplace{
		repository: repo,
		demoMode:   demoMode,
		gateways:   payment.NewRegistry(),
	}
}

func (s *Marketplace) CreateOrder(ctx context.Context, actor domain.Actor, input domain.CreateOrderInput, keys ...string) (domain.Order, error) {
	if actor.Role != domain.RoleCustomer {
		return domain.Order{}, ErrForbidden
	}
	if err := validateActor(actor); err != nil {
		return domain.Order{}, err
	}
	var err error
	input, err = normalizeInput(input)
	if err != nil {
		return domain.Order{}, err
	}
	key := ""
	if len(keys) > 0 {
		key = strings.TrimSpace(keys[0])
	}
	if err := validateKey(key); err != nil {
		return domain.Order{}, err
	}
	payload, err := json.Marshal(input)
	if err != nil {
		return domain.Order{}, err
	}
	hash := sha256.Sum256(payload)
	now := time.Now().UTC().Truncate(time.Millisecond)
	order := domain.Order{ID: newID("ord"), CustomerID: actor.ID, Category: input.Category, Equipment: input.Equipment, Issue: input.Issue, Address: input.Address, ScheduledAt: input.ScheduledAt, Status: domain.StatusPendingWorker, PaymentStatus: domain.PaymentNotStarted, CreatedAt: now, UpdatedAt: now}
	created, _, err := s.repository.CreateOrder(ctx, order, key, hex.EncodeToString(hash[:]))
	return created, err
}

func (s *Marketplace) ListOrders(ctx context.Context, actor domain.Actor, queries ...domain.ListQuery) ([]domain.Order, error) {
	if err := validateActor(actor); err != nil {
		return nil, err
	}
	query := domain.ListQuery{Actor: actor}
	if len(queries) > 0 {
		query = queries[0]
		query.Actor = actor
	}
	if s.workerGate != nil && actor.Role == domain.RoleWorker {
		approved, err := s.workerGate.CanAccept(ctx, actor.ID)
		if err != nil {
			return nil, err
		}
		query.OwnWorkerOnly = !approved
	}
	return s.repository.ListOrders(ctx, query)
}

func (s *Marketplace) Transition(
	ctx context.Context,
	actor domain.Actor,
	orderID string,
	action string,
	quoteCents int64,
) (domain.Order, error) {
	if err := validateActor(actor); err != nil {
		return domain.Order{}, err
	}
	if err := validateIdentifier(orderID); err != nil {
		return domain.Order{}, err
	}
	order, err := s.repository.GetOrder(ctx, orderID)
	if err != nil {
		return domain.Order{}, err
	}
	if actor.Demo && actor.Role == domain.RoleWorker && order.CustomerID != "customer-demo" {
		return domain.Order{}, ErrForbidden
	}
	expectedStatus := order.Status

	switch action {
	/// 师傅认领当前仍待接单的订单。
	case "accept":
		if err := s.requireApprovedWorker(ctx, actor); err != nil {
			return domain.Order{}, err
		}
		if actor.Role != domain.RoleWorker || actor.ID == "" ||
			order.Status != domain.StatusPendingWorker {
			return domain.Order{}, repository.ErrInvalidState
		}
		order.WorkerID = actor.ID
		order.Status = domain.StatusAccepted
	/// 已接单师傅登记到达现场。
	case "arrive":
		if !s.isAssignedWorker(actor, order) || order.Status != domain.StatusAccepted {
			return domain.Order{}, repository.ErrInvalidState
		}
		order.Status = domain.StatusArrived
	/// 师傅提交检测后的维修报价。
	case "quote":
		if !s.isAssignedWorker(actor, order) ||
			order.Status != domain.StatusArrived {
			return domain.Order{}, repository.ErrInvalidState
		}
		if quoteCents < 1 || quoteCents > domain.MaxQuoteCents {
			return domain.Order{}, fmt.Errorf("%w: quoteCents must be 1..%d", ErrInvalidInput, domain.MaxQuoteCents)
		}
		order.QuotedAmountCents = quoteCents
		order.Status = domain.StatusQuotePending
	/// 用户确认报价后才允许开始维修。
	case "confirm-quote":
		if actor.Role != domain.RoleCustomer ||
			actor.ID != order.CustomerID ||
			order.Status != domain.StatusQuotePending {
			return domain.Order{}, repository.ErrInvalidState
		}
		order.Status = domain.StatusInService
	/// 师傅提交完工，订单等待平台收款。
	case "complete":
		if !s.isAssignedWorker(actor, order) || order.Status != domain.StatusInService {
			return domain.Order{}, repository.ErrInvalidState
		}
		order.Status = domain.StatusAwaitingPay
	/// 用户只能取消尚未被师傅接单的订单。
	case "cancel":
		if actor.Role != domain.RoleCustomer ||
			actor.ID != order.CustomerID ||
			order.Status != domain.StatusPendingWorker {
			return domain.Order{}, repository.ErrInvalidState
		}
		order.Status = domain.StatusCancelled
	default:
		return domain.Order{}, fmt.Errorf("%w: unknown action", ErrInvalidInput)
	}

	order.UpdatedAt = time.Now().UTC().Truncate(time.Millisecond)
	if err := s.repository.SaveOrder(ctx, order, expectedStatus); err != nil {
		return domain.Order{}, err
	}
	return order, nil
}

func (s *Marketplace) DemoCollect(ctx context.Context, actor domain.Actor, orderID string) (domain.Order, error) {
	if !s.demoMode || (actor.Role != domain.RoleAdmin && actor.Role != domain.RoleOperator) {
		return domain.Order{}, ErrForbidden
	}
	if err := validateActor(actor); err != nil {
		return domain.Order{}, err
	}
	if err := validateIdentifier(orderID); err != nil {
		return domain.Order{}, err
	}
	order, err := s.repository.GetOrder(ctx, orderID)
	if err != nil {
		return domain.Order{}, err
	}
	if order.Status == domain.StatusCompleted && order.PaymentStatus == domain.PaymentDemoPaid {
		return order, nil
	}
	if order.Status != domain.StatusAwaitingPay || order.QuotedAmountCents <= 0 {
		return domain.Order{}, repository.ErrInvalidState
	}

	workerShare, platformFee, err := domain.SplitDemoAmount(order.QuotedAmountCents)
	if err != nil {
		return domain.Order{}, fmt.Errorf("%w: quote amount", ErrInvalidInput)
	}
	order.Status = domain.StatusCompleted
	order.PaymentStatus = domain.PaymentDemoPaid
	order.WorkerShareCents = workerShare
	order.PlatformFeeCents = platformFee
	order.ProfitRuleVersion = domain.ProfitRuleVersion
	order.UpdatedAt = time.Now().UTC().Truncate(time.Millisecond)
	settlement := domain.Settlement{
		ID:                newID("set"),
		OrderID:           order.ID,
		WorkerID:          order.WorkerID,
		GrossAmountCents:  order.QuotedAmountCents,
		PlatformFeeCents:  order.PlatformFeeCents,
		WorkerShareCents:  order.WorkerShareCents,
		ProfitRuleVersion: domain.ProfitRuleVersion,
		Status:            domain.SettlementPendingManual,
		CreatedAt:         time.Now().UTC().Truncate(time.Millisecond),
	}
	if err := s.repository.DemoCollect(domain.WithAuditActor(ctx, actor), order, settlement); err != nil {
		return s.resolveCollection(ctx, orderID, err)
	}
	return order, nil
}

func (s *Marketplace) resolveCollection(ctx context.Context, orderID string, cause error) (domain.Order, error) {
	uncertain := errors.Is(cause, repository.ErrRetryable)
	if !uncertain && !errors.Is(cause, repository.ErrInvalidState) {
		return domain.Order{}, cause
	}
	check, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	for {
		if err := ctx.Err(); err != nil {
			return domain.Order{}, err
		}
		current, err := s.repository.GetOrder(check, orderID)
		if err == nil {
			if current.Status == domain.StatusCompleted && current.PaymentStatus == domain.PaymentDemoPaid {
				return current, nil
			}
			if current.Status != domain.StatusAwaitingPay {
				return domain.Order{}, cause
			}
		} else if errors.Is(err, repository.ErrNotFound) {
			return domain.Order{}, cause
		}
		if !uncertain {
			return domain.Order{}, cause
		}
		// A competing commit can become visible after the first lookup; never repeat the money write here.
		timer := time.NewTimer(20 * time.Millisecond)
		select {
		case <-check.Done():
			timer.Stop()
			if err := ctx.Err(); err != nil {
				return domain.Order{}, err
			}
			return domain.Order{}, cause
		case <-timer.C:
		}
	}
}

func (s *Marketplace) CreatePaymentIntent(ctx context.Context, actor domain.Actor, input domain.PaymentIntentInput) (payment.Intent, error) {
	if actor.Role != domain.RoleCustomer {
		return payment.Intent{}, ErrForbidden
	}
	if err := validateActor(actor); err != nil {
		return payment.Intent{}, err
	}
	if err := validateIdentifier(input.OrderID); err != nil {
		return payment.Intent{}, err
	}
	provider := payment.Provider(strings.ToLower(strings.TrimSpace(input.Provider)))
	gateway, exists := s.gateways[provider]
	if !exists {
		return payment.Intent{}, fmt.Errorf("%w: unsupported provider", ErrInvalidInput)
	}
	order, err := s.repository.GetOrder(ctx, input.OrderID)
	if err != nil {
		return payment.Intent{}, err
	}
	if order.CustomerID != actor.ID {
		return payment.Intent{}, ErrForbidden
	}
	if order.Status != domain.StatusAwaitingPay {
		return payment.Intent{}, repository.ErrInvalidState
	}
	if _, _, err := domain.SplitDemoAmount(order.QuotedAmountCents); err != nil {
		return payment.Intent{}, ErrInvalidInput
	}
	intent, err := gateway.CreateIntent(ctx, payment.IntentRequest{OrderID: input.OrderID, AmountCents: order.QuotedAmountCents, Currency: "CNY"})
	if err != nil {
		if errors.Is(err, payment.ErrProviderNotConfigured) {
			return payment.Intent{}, ErrPaymentPending
		}
		return payment.Intent{}, err
	}
	return intent, nil
}

func (s *Marketplace) Ready(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	return s.repository.Ready(ctx)
}

func (s *Marketplace) Dashboard(ctx context.Context) (domain.Dashboard, error) {
	return s.repository.Dashboard(ctx)
}

func (s *Marketplace) ListWorkers(ctx context.Context, query domain.ListQuery) ([]domain.Worker, error) {
	beforeID := ""
	if query.Before != nil {
		beforeID = query.Before.ID
	}
	return s.repository.ListWorkers(ctx, query.PageSize(), beforeID)
}

func (s *Marketplace) ListSettlements(ctx context.Context, query domain.ListQuery) ([]domain.Settlement, error) {
	return s.repository.ListSettlements(ctx, query)
}

func (s *Marketplace) MarkSettlementManuallyPaid(ctx context.Context, actor domain.Actor, settlementID string) error {
	if actor.Role != domain.RoleAdmin && actor.Role != domain.RoleOperator {
		return ErrForbidden
	}
	if err := validateActor(actor); err != nil {
		return err
	}
	if err := validateIdentifier(settlementID); err != nil {
		return err
	}
	return s.repository.MarkSettlementManuallyPaid(domain.WithAuditActor(ctx, actor), settlementID)
}

func (s *Marketplace) isAssignedWorker(actor domain.Actor, order domain.Order) bool {
	return actor.Role == domain.RoleWorker && actor.ID != "" && actor.ID == order.WorkerID
}

func newID(prefix string) string {
	value := make([]byte, 10)
	if _, err := rand.Read(value); err != nil {
		return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
	}
	randomPart := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(value)
	return prefix + "_" + strings.TrimRight(randomPart, "=")
}
