package identity

import (
	"context"
	"net/url"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"repair-platform/internal/service"
)

func normalizeDevice(device Device, desktopOnly bool) (Device, error) {
	if device.Kind == "" {
		device.Kind = "desktop"
	}
	device.Label = strings.TrimSpace(device.Label)
	device.Platform = strings.TrimSpace(device.Platform)
	if (device.Kind != "mobile" && device.Kind != "desktop") || (desktopOnly && device.Kind != "desktop") || !utf8.ValidString(device.Label) || !utf8.ValidString(device.Platform) || utf8.RuneCountInString(device.Label) > 80 || utf8.RuneCountInString(device.Platform) > 40 {
		return Device{}, service.ErrInvalidInput
	}
	for _, value := range []string{device.Label, device.Platform} {
		for _, r := range value {
			if unicode.IsControl(r) {
				return Device{}, service.ErrInvalidInput
			}
		}
	}
	if device.Label == "" {
		device.Label = device.Kind
	}
	return device, nil
}

func HasCapability(user User, capability string) bool {
	if user.Session == nil {
		return false
	}
	for _, value := range user.Session.Capabilities {
		if value == capability {
			return true
		}
	}
	return false
}

func (s *Service) Devices(ctx context.Context, user User) ([]SessionInfo, error) {
	if !HasCapability(user, "manage_devices") {
		return nil, service.ErrForbidden
	}
	values, err := s.store.ListSessions(ctx, user.ID, time.Now().UTC())
	if err != nil {
		return nil, err
	}
	for i := range values {
		values[i].IsCurrent = values[i].ID == user.Session.ID
	}
	return values, nil
}
func (s *Service) RevokeDevice(ctx context.Context, user User, id string) error {
	if !HasCapability(user, "manage_devices") {
		return service.ErrForbidden
	}
	if len(id) > 64 || !strings.HasPrefix(id, "dev_") {
		return service.ErrInvalidInput
	}
	return s.store.RevokeDevice(ctx, user.ID, id)
}

func (s *Service) NewChallenge(ctx context.Context, device Device) (ChallengeResult, error) {
	device, err := normalizeDevice(device, true)
	if err != nil {
		return ChallengeResult{}, err
	}
	now := time.Now().UTC().Truncate(time.Millisecond)
	poll, approval := randomText(), randomText()
	value := Challenge{ID: "qr_" + randomText()[:32], Device: device, Status: "pending", CreatedAt: now, ExpiresAt: now.Add(2 * time.Minute), PollHash: tokenHash(poll), ApprovalHash: tokenHash(approval)}
	if err := s.store.CreateChallenge(ctx, value); err != nil {
		return ChallengeResult{}, err
	}
	parameters := url.Values{"challengeId": {value.ID}, "approvalCode": {approval}}
	return ChallengeResult{Challenge: value, PollToken: poll, QRPayload: "repairmarketplace://login?" + parameters.Encode()}, nil
}

func (s *Service) InspectChallenge(ctx context.Context, user User, id, code string) (Challenge, error) {
	if !HasCapability(user, "authorize_qr") {
		return Challenge{}, service.ErrForbidden
	}
	if len(code) != 43 || len(id) > 64 {
		return Challenge{}, service.ErrInvalidInput
	}
	value, err := s.store.GetChallenge(ctx, id)
	if err != nil {
		return Challenge{}, err
	}
	if !equalHash(value.ApprovalHash, tokenHash(code)) {
		return Challenge{}, ErrUnauthenticated
	}
	if !value.ExpiresAt.After(time.Now().UTC()) {
		value.Status = "expired"
	}
	return value, nil
}

func (s *Service) ApproveChallenge(ctx context.Context, user User, id, code, decision string) error {
	if !HasCapability(user, "authorize_qr") {
		return service.ErrForbidden
	}
	if (decision != "approve" && decision != "reject") || len(code) != 43 || len(id) > 64 {
		return service.ErrInvalidInput
	}
	return authTransactionError(s.store.ApproveChallenge(ctx, id, tokenHash(code), user.ID, decision, time.Now().UTC()))
}

func (s *Service) PollChallenge(ctx context.Context, id, pollToken string) (PollResult, error) {
	if len(pollToken) != 43 || len(id) > 64 {
		return PollResult{}, service.ErrInvalidInput
	}
	now := time.Now().UTC().Truncate(time.Millisecond)
	token := randomText()
	// A QR credential can only create a desktop session, regardless of caller claims.
	value := Session{ID: "dev_" + randomText()[:32], Hash: tokenHash(token), AuthMethod: "qr", CreatedAt: now, ExpiresAt: now.Add(s.ttl)}
	user, status, err := s.store.RedeemChallenge(ctx, id, tokenHash(pollToken), value, now)
	if err != nil {
		return PollResult{}, authTransactionError(err)
	}
	if status != "approved" {
		return PollResult{Status: status}, nil
	}
	return PollResult{Status: status, Auth: &Result{Token: token, ExpiresAt: value.ExpiresAt, User: user, Session: *user.Session}}, nil
}
