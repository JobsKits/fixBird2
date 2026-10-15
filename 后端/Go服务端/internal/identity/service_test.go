package identity

import (
	"context"
	"errors"
	"net/url"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
)

func TestPasswordsAndRegistrationBoundary(t *testing.T) {
	a, err := hashPassword("test-password-long")
	if err != nil {
		t.Fatal(err)
	}
	b, _ := hashPassword("test-password-long")
	if a == b || !verifyPassword("test-password-long", a) || verifyPassword("wrong-password", a) || verifyPassword("test-password-long", "broken") {
		t.Fatal("password KDF/salt boundary")
	}
	accounts, err := NewService(NewMemory(), time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if _, err := accounts.Register(ctx, RegisterInput{Username: "administrator", Password: "test-password-long", DisplayName: "测试", Role: domain.RoleAdmin}); !errors.Is(err, service.ErrInvalidInput) {
		t.Fatal("public admin registration", err)
	}
	if _, err := accounts.Register(ctx, RegisterInput{Username: "short-password", Password: "short", DisplayName: "测试", Role: domain.RoleCustomer}); !errors.Is(err, service.ErrInvalidInput) {
		t.Fatal("short password", err)
	}
	if err := accounts.BootstrapAdmin(ctx, "", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := accounts.Login(ctx, LoginInput{Username: "missing", Password: "test-password-long"}); !errors.Is(err, ErrCredentials) {
		t.Fatal(err)
	}
}

func TestIndependentDevicesAndOneTimeQR(t *testing.T) {
	store := NewMemory()
	accounts, _ := NewService(store, time.Hour)
	ctx := context.Background()
	mobile, err := accounts.Register(ctx, RegisterInput{Username: "test-worker", Password: "test-password-long", DisplayName: "测试师傅", Role: domain.RoleWorker, Device: Device{Kind: "mobile", Label: "测试手机"}})
	if err != nil {
		t.Fatal(err)
	}
	desktop, err := accounts.Login(ctx, LoginInput{Username: "test-worker", Password: "test-password-long", Device: Device{Kind: "desktop", Label: "测试电脑"}})
	if err != nil {
		t.Fatal(err)
	}
	if HasCapability(desktop.User, "authorize_qr") || !HasCapability(mobile.User, "authorize_qr") {
		t.Fatal("password device capabilities")
	}
	if err := accounts.Logout(ctx, mobile.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := accounts.Authenticate(ctx, mobile.Token); !errors.Is(err, ErrUnauthenticated) {
		t.Fatal("phone logout", err)
	}
	if _, err := accounts.Authenticate(ctx, desktop.Token); err != nil {
		t.Fatal("phone logout revoked PC", err)
	}
	mobile, err = accounts.Login(ctx, LoginInput{Username: "test-worker", Password: "test-password-long", Device: Device{Kind: "mobile"}})
	if err != nil {
		t.Fatal(err)
	}
	challenge, err := accounts.NewChallenge(ctx, Device{Kind: "desktop", Label: "扫码电脑"})
	if err != nil {
		t.Fatal(err)
	}
	uri, _ := url.Parse(challenge.QRPayload)
	code := uri.Query().Get("approvalCode")
	if _, err := accounts.PollChallenge(ctx, challenge.ID, challenge.PollToken); err != nil {
		t.Fatal(err)
	}
	if _, err := accounts.InspectChallenge(ctx, desktop.User, challenge.ID, code); !errors.Is(err, service.ErrForbidden) {
		t.Fatal("desktop can authorize QR", err)
	}
	if _, err := accounts.InspectChallenge(ctx, mobile.User, challenge.ID, code); err != nil {
		t.Fatal(err)
	}
	if err := accounts.ApproveChallenge(ctx, mobile.User, challenge.ID, code, "approve"); err != nil {
		t.Fatal(err)
	}
	var delivered atomic.Int64
	var group sync.WaitGroup
	results := make(chan Result, 16)
	for i := 0; i < 16; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			result, err := accounts.PollChallenge(ctx, challenge.ID, challenge.PollToken)
			if err != nil {
				t.Error(err)
				return
			}
			if result.Auth != nil {
				delivered.Add(1)
				results <- *result.Auth
			} else if result.Status != "consumed" {
				t.Error("unexpected replay status", result.Status)
			}
		}()
	}
	group.Wait()
	close(results)
	if delivered.Load() != 1 {
		t.Fatal("QR delivered more than once", delivered.Load())
	}
	var qr Result
	for result := range results {
		qr = result
	}
	if qr.Session.AuthMethod != "qr" || qr.Session.Device.Kind != "desktop" || len(qr.Session.Capabilities) != 0 {
		t.Fatal("QR privileges elevated")
	}
	if err := accounts.RevokeDevice(ctx, qr.User, desktop.Session.ID); !errors.Is(err, service.ErrForbidden) {
		t.Fatal("QR revoked device", err)
	}
	if err := accounts.RevokeDevice(ctx, mobile.User, "dev_missing"); !errors.Is(err, repository.ErrNotFound) {
		t.Fatal(err)
	}
	if err := accounts.RevokeDevice(ctx, mobile.User, qr.Session.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := accounts.Authenticate(ctx, qr.Token); !errors.Is(err, ErrUnauthenticated) {
		t.Fatal("device revoke ignored", err)
	}
	if _, err := accounts.Authenticate(ctx, desktop.Token); err != nil {
		t.Fatal("selective revoke changed other PC", err)
	}
	store.mu.Lock()
	for hash, value := range store.sessions {
		value.ExpiresAt = time.Now().Add(-time.Minute)
		store.sessions[hash] = value
	}
	store.mu.Unlock()
	if _, err := accounts.Authenticate(ctx, desktop.Token); !errors.Is(err, ErrUnauthenticated) {
		t.Fatal("expiry ignored", err)
	}
}
