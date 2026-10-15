package identity

import (
	"context"
	"errors"
	"net/url"
	"strings"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/repository"
)

func TestQRRejectedExpiredAndSecrets(t *testing.T) {
	ctx := context.Background()
	store := NewMemory()
	accounts, _ := NewService(store, time.Hour)
	user := User{ID: "usr_qr_fixture", Username: "qr-fixture", Role: domain.RoleCustomer, DisplayName: "测试", Session: &SessionInfo{Capabilities: []string{"authorize_qr"}}}
	challenge, err := accounts.NewChallenge(ctx, Device{Kind: "desktop"})
	if err != nil {
		t.Fatal(err)
	}
	uri, _ := url.Parse(challenge.QRPayload)
	code := uri.Query().Get("approvalCode")
	if _, err := accounts.PollChallenge(ctx, challenge.ID, strings.Repeat("a", 43)); !errors.Is(err, ErrUnauthenticated) {
		t.Fatal("bad poll secret", err)
	}
	if err := accounts.ApproveChallenge(ctx, user, challenge.ID, strings.Repeat("a", 43), "approve"); !errors.Is(err, ErrUnauthenticated) {
		t.Fatal("bad approval secret", err)
	}
	if err := accounts.ApproveChallenge(ctx, user, challenge.ID, code, "reject"); err != nil {
		t.Fatal(err)
	}
	if result, err := accounts.PollChallenge(ctx, challenge.ID, challenge.PollToken); err != nil || result.Status != "rejected" || result.Auth != nil {
		t.Fatal("rejected challenge", result.Status, err)
	}
	if err := accounts.ApproveChallenge(ctx, user, challenge.ID, code, "approve"); !errors.Is(err, repository.ErrInvalidState) {
		t.Fatal("rejected challenge replay", err)
	}
	challenge, err = accounts.NewChallenge(ctx, Device{Kind: "desktop"})
	if err != nil {
		t.Fatal(err)
	}
	uri, _ = url.Parse(challenge.QRPayload)
	code = uri.Query().Get("approvalCode")
	store.mu.Lock()
	expired := store.challenges[challenge.ID]
	expired.ExpiresAt = time.Now().Add(-time.Minute)
	store.challenges[challenge.ID] = expired
	store.mu.Unlock()
	if result, err := accounts.InspectChallenge(ctx, user, challenge.ID, code); err != nil || result.Status != "expired" {
		t.Fatal("inspect expiry", result.Status, err)
	}
	if err := accounts.ApproveChallenge(ctx, user, challenge.ID, code, "approve"); !errors.Is(err, repository.ErrInvalidState) {
		t.Fatal("expired approval", err)
	}
	if result, err := accounts.PollChallenge(ctx, challenge.ID, challenge.PollToken); err != nil || result.Status != "expired" || result.Auth != nil {
		t.Fatal("expired challenge", result.Status, err)
	}
	if _, err := accounts.NewChallenge(ctx, Device{Kind: "mobile"}); err == nil {
		t.Fatal("QR challenge can claim mobile")
	}
}
