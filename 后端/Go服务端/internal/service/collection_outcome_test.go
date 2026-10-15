// Created by Jobs on 2026年10月14日，星期三.
package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/repository"
)

type delayedCollection struct {
	repository.Repository
	order      domain.Order
	final      domain.Order
	reads      int
	writes     int
	visibleAt  int
	cause      error
	afterWrite func()
}

func (r *delayedCollection) GetOrder(ctx context.Context, id string) (domain.Order, error) {
	if err := ctx.Err(); err != nil {
		return domain.Order{}, err
	}
	r.reads++
	if r.writes > 0 && r.visibleAt > 0 && r.reads >= r.visibleAt {
		return r.final, nil
	}
	return r.order, nil
}

func (r *delayedCollection) DemoCollect(_ context.Context, _ domain.Order, _ domain.Settlement) error {
	r.writes++
	if r.afterWrite != nil {
		r.afterWrite()
	}
	return r.cause
}

func collectionFixture() *delayedCollection {
	order := domain.Order{ID: "ord_outcome", WorkerID: "worker-demo", Status: domain.StatusAwaitingPay, QuotedAmountCents: 100}
	final := order
	final.Status, final.PaymentStatus = domain.StatusCompleted, domain.PaymentDemoPaid
	final.WorkerShareCents, final.PlatformFeeCents = 90, 10
	final.ProfitRuleVersion = domain.ProfitRuleVersion
	return &delayedCollection{order: order, final: final, visibleAt: 4, cause: repository.ErrRetryable}
}

func TestCollectionResolvesDelayedCompetingCommitWithoutRepeatingWrite(t *testing.T) {
	r := collectionFixture()
	s := NewMarketplace(r, true)
	order, err := s.DemoCollect(context.Background(), admin(), r.order.ID)
	if err != nil || order.Status != domain.StatusCompleted || order.PaymentStatus != domain.PaymentDemoPaid || r.reads < r.visibleAt || r.writes != 1 {
		t.Fatalf("delayed outcome: order=%+v err=%v reads=%d writes=%d", order, err, r.reads, r.writes)
	}
}

func TestCollectionUnresolvedOutcomeIsBoundedAndDoesNotRepeatWrite(t *testing.T) {
	r := collectionFixture()
	r.visibleAt = 0
	s := NewMarketplace(r, true)
	start := time.Now()
	_, err := s.DemoCollect(context.Background(), admin(), r.order.ID)
	if !errors.Is(err, repository.ErrRetryable) || r.writes != 1 || time.Since(start) > 2*time.Second {
		t.Fatalf("unresolved outcome: err=%v elapsed=%s writes=%d", err, time.Since(start), r.writes)
	}
}

func TestCollectionOutcomeHonorsCallerCancellation(t *testing.T) {
	r := collectionFixture()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	r.afterWrite = cancel
	s := NewMarketplace(r, true)
	_, err := s.DemoCollect(ctx, admin(), r.order.ID)
	if !errors.Is(err, context.Canceled) || r.writes != 1 {
		t.Fatalf("cancelled outcome: err=%v writes=%d", err, r.writes)
	}
}

func TestCollectionDoesNotTurnTerminalOrPermanentErrorsIntoSuccess(t *testing.T) {
	for _, name := range []string{"other_terminal_state", "permanent_error"} {
		t.Run(name, func(t *testing.T) {
			r := collectionFixture()
			if name == "other_terminal_state" {
				r.final.Status = domain.StatusCancelled
				r.final.PaymentStatus = domain.PaymentNotStarted
				r.visibleAt = 2
			} else {
				r.cause = errors.New("permanent synthetic storage failure")
			}
			_, err := NewMarketplace(r, true).DemoCollect(context.Background(), admin(), r.order.ID)
			if !errors.Is(err, r.cause) || r.writes != 1 {
				t.Fatalf("non-success outcome: err=%v writes=%d", err, r.writes)
			}
		})
	}
}
