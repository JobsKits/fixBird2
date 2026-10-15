package repository_test

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/png"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

func TestIdentityWorkerContract(t *testing.T) {
	for _, backend := range []string{"memory", "tidb-pessimistic", "tidb-optimistic"} {
		t.Run(backend, func(t *testing.T) {
			ctx := context.Background()
			memory := repository.NewMemory()
			var repo repository.Repository = memory
			var accountsStore identity.Store = identity.NewMemory()
			var onboardingStore workers.Store = workers.NewMemory(memory.UpsertWorker)
			if backend != "memory" {
				db := testTiDB(t, strings.TrimPrefix(backend, "tidb-")).(*repository.TiDB)
				db.EnforceWorkerApproval()
				repo = db
				accountsStore = identity.NewTiDB(db.DB())
				onboardingStore = workers.NewTiDB(db.DB())
			} else {
				memory.EnforceWorkerApproval()
			}
			accounts, err := identity.NewService(accountsStore, time.Hour)
			if err != nil {
				t.Fatal(err)
			}
			onboarding, err := workers.NewService(onboardingStore, t.TempDir())
			if err != nil {
				t.Fatal(err)
			}
			marketplace := service.NewMarketplace(repo, true)
			marketplace.SetWorkerGate(onboarding)
			worker, err := accounts.Register(ctx, identity.RegisterInput{Username: "worker-contract", Password: "contract-password-long", DisplayName: "测试师傅", Role: domain.RoleWorker, Device: identity.Device{Kind: "mobile"}})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Authenticate(ctx, worker.Token); err != nil {
				t.Fatal(err)
			}
			other := identity.User{ID: "usr_other_contract", Username: "other-contract", DisplayName: "另一测试账号", Role: domain.RoleCustomer, PasswordHash: "fixture-not-for-login", CreatedAt: time.Now().UTC().Truncate(time.Millisecond)}
			if err := accountsStore.CreateUser(ctx, other); err != nil {
				t.Fatal(err)
			}
			otherSession := identity.Session{ID: "dev_other_contract", Hash: strings.Repeat("a", 64), UserID: other.ID, Device: identity.Device{Kind: "desktop"}, AuthMethod: "password", CreatedAt: other.CreatedAt, ExpiresAt: other.CreatedAt.Add(time.Hour)}
			if err := accountsStore.CreateSession(ctx, otherSession); err != nil {
				t.Fatal(err)
			}
			if err := accounts.RevokeDevice(ctx, worker.User, otherSession.ID); !errors.Is(err, repository.ErrNotFound) {
				t.Fatal("cross-account device revocation", err)
			}
			if _, err := accountsStore.SessionUser(ctx, otherSession.Hash, time.Now().UTC()); err != nil {
				t.Fatal("foreign session was revoked", err)
			}
			if orders, err := marketplace.ListOrders(ctx, worker.User.Actor()); err != nil || len(orders) != 0 {
				t.Fatal("unapproved pending order access", orders, err)
			}
			if _, err := onboarding.Get(ctx, worker.User.Actor()); !errors.Is(err, repository.ErrNotFound) {
				t.Fatal("initial application", err)
			}
			var pngData bytes.Buffer
			_ = png.Encode(&pngData, image.NewRGBA(image.Rect(0, 0, 2, 2)))
			asset, err := onboarding.Upload(ctx, worker.User.Actor(), bytes.NewReader(pngData.Bytes()))
			if err != nil {
				t.Fatal(err)
			}
			if _, _, err := onboarding.ReadAsset(ctx, domain.Actor{ID: "other-worker", Role: domain.RoleWorker}, asset.ID); !errors.Is(err, service.ErrForbidden) {
				t.Fatal("asset leaked", err)
			}
			if _, err := onboarding.Upload(ctx, worker.User.Actor(), strings.NewReader("not an image")); !errors.Is(err, service.ErrInvalidInput) {
				t.Fatal("non-image accepted", err)
			}
			input := workers.SubmitInput{DisplayName: "测试师傅", ContactPhone: "联系字段测试", ServiceAreas: []string{"测试城区"}, Skills: []string{"家电维修"}, AssetIDs: []string{asset.ID}}
			application, err := onboarding.Submit(ctx, worker.User.Actor(), input)
			if err != nil || application.Status != "pending" || application.Revision != 1 {
				t.Fatal(application, err)
			}
			admin := domain.Actor{ID: "contract-admin", Role: domain.RoleAdmin}
			rejected, err := onboarding.Review(ctx, admin, application.ID, workers.ReviewInput{Decision: "rejected", Note: "请补充资料", ExpectedRevision: 1})
			if err != nil || rejected.Status != "rejected" {
				t.Fatal(rejected, err)
			}
			input.ExpectedRevision = 1
			application, err = onboarding.Submit(ctx, worker.User.Actor(), input)
			if err != nil || application.Revision != 2 {
				t.Fatal(application, err)
			}
			if _, err := onboarding.Review(ctx, admin, application.ID, workers.ReviewInput{Decision: "approved", ExpectedRevision: 1}); !errors.Is(err, workers.ErrRevisionConflict) {
				t.Fatal("stale approval", err)
			}
			if _, err := onboarding.Review(ctx, admin, application.ID, workers.ReviewInput{Decision: "approved", ExpectedRevision: 2}); err != nil {
				t.Fatal(err)
			}
			now := time.Now().UTC().Truncate(time.Millisecond)
			order := domain.Order{ID: "ord_worker_gate", CustomerID: "customer-demo", Category: "家电维修", Equipment: "测试", Issue: "测试", Address: "测试", Status: domain.StatusPendingWorker, PaymentStatus: domain.PaymentNotStarted, CreatedAt: now, UpdatedAt: now}
			if _, _, err := repo.CreateOrder(ctx, order, "", ""); err != nil {
				t.Fatal(err)
			}
			realOrder := order
			realOrder.ID = "ord_registered_customer"
			realOrder.CustomerID = other.ID
			if _, _, err := repo.CreateOrder(ctx, realOrder, "", ""); err != nil {
				t.Fatal(err)
			}
			if values, err := marketplace.ListOrders(ctx, worker.User.Actor()); err != nil || len(values) != 2 {
				t.Fatal("approved worker cannot access normal pool", values, err)
			}
			if values, err := repo.ListOrders(ctx, domain.ListQuery{Actor: domain.Actor{ID: "worker-demo", Role: domain.RoleWorker, Demo: true}, Limit: 100}); err != nil || len(values) != 1 || values[0].ID != order.ID {
				t.Fatal("demo worker exposed registered customer", values, err)
			}
			if _, err := marketplace.Transition(ctx, worker.User.Actor(), order.ID, "accept", 0); err != nil {
				t.Fatal("approved accept", err)
			}
			input.ExpectedRevision = 2
			if _, err := onboarding.Submit(ctx, worker.User.Actor(), input); err != nil {
				t.Fatal(err)
			}
			order.ID = "ord_worker_gate_pending"
			if _, _, err := repo.CreateOrder(ctx, order, "", ""); err != nil {
				t.Fatal(err)
			}
			order.Status = domain.StatusAccepted
			order.WorkerID = worker.User.ID
			if err := repo.SaveOrder(ctx, order, domain.StatusPendingWorker); !errors.Is(err, repository.ErrWorkerNotApproved) {
				t.Fatal("repository approval bypass", err)
			}
			if orders, err := marketplace.ListOrders(ctx, worker.User.Actor()); err != nil || len(orders) != 1 || orders[0].ID != "ord_worker_gate" {
				t.Fatal("resubmission hid assigned order or exposed pending pool", orders, err)
			}
			challenge, err := accounts.NewChallenge(ctx, identity.Device{Kind: "desktop", Label: "合同电脑"})
			if err != nil {
				t.Fatal(err)
			}
			uri, _ := url.Parse(challenge.QRPayload)
			code := uri.Query().Get("approvalCode")
			if err := accounts.ApproveChallenge(ctx, worker.User, challenge.ID, code, "approve"); err != nil {
				t.Fatal(err)
			}
			var group sync.WaitGroup
			var delivered atomic.Int64
			authResults := make(chan identity.Result, 8)
			for i := 0; i < 8; i++ {
				group.Add(1)
				go func() {
					defer group.Done()
					for attempt := 0; attempt < 4; attempt++ {
						result, err := accounts.PollChallenge(ctx, challenge.ID, challenge.PollToken)
						if errors.Is(err, repository.ErrRetryable) {
							time.Sleep(20 * time.Millisecond)
							continue
						}
						if err != nil {
							t.Errorf("QR concurrent poll: %v", err)
							return
						}
						if result.Auth != nil {
							delivered.Add(1)
							authResults <- *result.Auth
						} else if result.Status != "consumed" {
							t.Error(result.Status)
						}
						return
					}
					t.Error("QR poll did not settle")
				}()
			}
			group.Wait()
			close(authResults)
			if delivered.Load() != 1 {
				t.Fatal("QR multiple exchange", delivered.Load())
			}
			var desktop identity.Result
			for result := range authResults {
				desktop = result
			}
			if len(desktop.Session.Capabilities) != 0 {
				t.Fatal("QR session gained phone capabilities")
			}
			if err := accounts.Logout(ctx, worker.Token); err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Authenticate(ctx, desktop.Token); err != nil {
				t.Fatal("phone logout revoked QR PC", err)
			}
			if err := accountsStore.Ready(ctx); err != nil {
				t.Fatal(err)
			}
			if err := onboardingStore.Ready(ctx); err != nil {
				t.Fatal(err)
			}
		})
	}
}
