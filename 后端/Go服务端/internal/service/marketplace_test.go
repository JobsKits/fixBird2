package service

import (
	"context"
	"errors"
	"strings"
	"testing"

	"repair-platform/internal/domain"
	"repair-platform/internal/payment"
	"repair-platform/internal/repository"
)

func customer() domain.Actor { return domain.Actor{ID: "customer-demo", Role: domain.RoleCustomer} }
func worker() domain.Actor   { return domain.Actor{ID: "worker-demo", Role: domain.RoleWorker} }
func admin() domain.Actor    { return domain.Actor{ID: "admin-demo", Role: domain.RoleAdmin} }
func validInput() domain.CreateOrderInput {
	return domain.CreateOrderInput{Category: "家电维修", Equipment: "冰箱", Issue: "不制冷", Address: "测试地址", ScheduledAt: "2026-10-10T10:00:00+08:00"}
}

func servicePayable(t *testing.T, m *Marketplace, quote int64) domain.Order {
	t.Helper()
	ctx := context.Background()
	order, err := m.CreateOrder(ctx, customer(), validInput(), "service-key")
	if err != nil {
		t.Fatal(err)
	}
	for _, action := range []string{"accept", "arrive", "quote", "confirm-quote", "complete"} {
		actor := worker()
		if action == "confirm-quote" {
			actor = customer()
		}
		order, err = m.Transition(ctx, actor, order.ID, action, quote)
		if err != nil {
			t.Fatal(action, err)
		}
	}
	return order
}

func TestBusinessFlowAndValidation(t *testing.T) {
	m := NewMarketplace(repository.NewMemory(), true)
	ctx := context.Background()
	first, err := m.CreateOrder(ctx, customer(), validInput(), "service-key")
	if err != nil {
		t.Fatal(err)
	}
	again, err := m.CreateOrder(ctx, customer(), validInput(), "service-key")
	if err != nil || again.ID != first.ID {
		t.Fatal(again, err)
	}
	changed := validInput()
	changed.Issue = "different"
	if _, err := m.CreateOrder(ctx, customer(), changed, "service-key"); !errors.Is(err, repository.ErrIdempotencyConflict) {
		t.Fatal(err)
	}
	other := domain.Actor{ID: "customer-other", Role: domain.RoleCustomer}
	orders, err := m.ListOrders(ctx, other)
	if err != nil || len(orders) != 0 {
		t.Fatal("customer isolation", orders, err)
	}
	if _, err := m.Transition(ctx, other, first.ID, "cancel", 0); !errors.Is(err, repository.ErrInvalidState) {
		t.Fatal("cancel ownership", err)
	}
	for _, input := range []domain.CreateOrderInput{{}, {Category: "invalid", Equipment: "x", Issue: "x", Address: "x"}, {Category: "家电维修", Equipment: strings.Repeat("字", 161), Issue: "x", Address: "x"}, {Category: "家电维修", Equipment: "x", Issue: "x", Address: "x", ScheduledAt: "明天"}} {
		if _, err := m.CreateOrder(ctx, customer(), input); !errors.Is(err, ErrInvalidInput) {
			t.Fatal("invalid input accepted", input, err)
		}
	}
	order := servicePayable(t, m, 10)
	paid, err := m.DemoCollect(ctx, admin(), order.ID)
	if err != nil || paid.WorkerShareCents != 9 || paid.PlatformFeeCents != 1 || paid.ProfitRuleVersion != domain.ProfitRuleVersion {
		t.Fatal(paid, err)
	}
	againPaid, err := m.DemoCollect(ctx, admin(), order.ID)
	if err != nil || againPaid.ID != paid.ID || againPaid.PlatformFeeCents != paid.PlatformFeeCents {
		t.Fatal("collection retry was not idempotent", againPaid, err)
	}
}

type captureGateway struct{ request payment.IntentRequest }

func (*captureGateway) Provider() payment.Provider { return payment.ProviderWeChat }
func (g *captureGateway) CreateIntent(_ context.Context, input payment.IntentRequest) (payment.Intent, error) {
	g.request = input
	return payment.Intent{Provider: payment.ProviderWeChat, Reference: "test-reference", RedirectURL: "https://example.invalid/intent"}, nil
}

func TestPaymentRemainsDisabledAndAdapterContract(t *testing.T) {
	m := NewMarketplace(repository.NewMemory(), true)
	order := servicePayable(t, m, 12850)
	for _, provider := range []string{"wechat", "alipay", "aggregate"} {
		if _, err := m.CreatePaymentIntent(context.Background(), customer(), domain.PaymentIntentInput{OrderID: order.ID, Provider: provider}); !errors.Is(err, ErrPaymentPending) {
			t.Fatal(provider, err)
		}
	}
	if _, err := m.CreatePaymentIntent(context.Background(), domain.Actor{ID: "customer-other", Role: domain.RoleCustomer}, domain.PaymentIntentInput{OrderID: order.ID, Provider: "wechat"}); !errors.Is(err, ErrForbidden) {
		t.Fatal("payment ownership", err)
	}
	if _, err := m.CreatePaymentIntent(context.Background(), customer(), domain.PaymentIntentInput{OrderID: "nonexistent", Provider: "wechat"}); !errors.Is(err, repository.ErrNotFound) {
		t.Fatal("payment order", err)
	}
	gateway := &captureGateway{}
	m.gateways[payment.ProviderWeChat] = gateway
	intent, err := m.CreatePaymentIntent(context.Background(), customer(), domain.PaymentIntentInput{OrderID: order.ID, Provider: "wechat"})
	if err != nil || gateway.request.AmountCents != 12850 || gateway.request.Currency != "CNY" || intent.Reference != "test-reference" || intent.RedirectURL == "" {
		t.Fatal(intent, gateway.request, err)
	}
}

func TestQuoteBounds(t *testing.T) {
	for _, amount := range []int64{0, -1, domain.MaxQuoteCents + 1} {
		m := NewMarketplace(repository.NewMemory(), true)
		order, err := m.CreateOrder(context.Background(), customer(), validInput())
		if err != nil {
			t.Fatal(err)
		}
		for _, action := range []string{"accept", "arrive"} {
			order, err = m.Transition(context.Background(), worker(), order.ID, action, 0)
			if err != nil {
				t.Fatal(err)
			}
		}
		if _, err := m.Transition(context.Background(), worker(), order.ID, "quote", amount); !errors.Is(err, ErrInvalidInput) {
			t.Fatal("accepted quote", amount, err)
		}
	}
}
