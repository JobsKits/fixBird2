package identity

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	"repair-platform/internal/domain"
	"repair-platform/internal/service"
)

type AccountInput struct {
	Username    string      `json:"username"`
	Password    string      `json:"password"`
	DisplayName string      `json:"displayName"`
	Role        domain.Role `json:"role"`
}
type AccountResult struct {
	User User `json:"user"`
}
type PasswordResetInput struct {
	RecoveryCode string `json:"recoveryCode"`
	Username     string `json:"username"`
	Password     string `json:"password"`
}

func (s *Service) createAccount(ctx context.Context, input AccountInput) (AccountResult, error) {
	input.Username = normalizeUsername(input.Username)
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	if (input.Role != domain.RoleAdmin && input.Role != domain.RoleOperator) || input.Username == "admin" || !usernamePattern.MatchString(input.Username) || !validPassword(input.Password) || !utf8.ValidString(input.DisplayName) || input.DisplayName == "" || utf8.RuneCountInString(input.DisplayName) > 120 {
		return AccountResult{}, service.ErrInvalidInput
	}
	if err := s.acquire(ctx); err != nil {
		return AccountResult{}, err
	}
	defer func() { <-s.semaphore }()
	hash, err := hashPassword(input.Password)
	if err != nil {
		return AccountResult{}, err
	}
	user := User{ID: "usr_" + randomText()[:32], Username: input.Username, DisplayName: input.DisplayName, Role: input.Role, Status: "active", PasswordHash: hash, CreatedAt: time.Now().UTC().Truncate(time.Millisecond)}
	if err := s.store.CreateUser(ctx, user); err != nil {
		return AccountResult{}, err
	}
	return AccountResult{User: user}, nil
}
func (s *Service) AddAccount(ctx context.Context, primary User, input AccountInput) (AccountResult, error) {
	if primary.Role != domain.RoleAdmin {
		return AccountResult{}, service.ErrForbidden
	}
	return s.createAccount(ctx, input)
}
func (s *Service) Accounts(ctx context.Context, primary User, after string) ([]User, error) {
	if primary.Role != domain.RoleAdmin {
		return nil, service.ErrForbidden
	}
	if after != "" && !usernamePattern.MatchString(after) {
		return nil, service.ErrInvalidInput
	}
	return s.store.ListAccounts(ctx, after)
}
func (s *Service) SetAccountStatus(ctx context.Context, admin User, username, status string) error {
	if admin.Role != domain.RoleAdmin {
		return service.ErrForbidden
	}
	if !usernamePattern.MatchString(username) || username == admin.Username || (status != "active" && status != "disabled") {
		return service.ErrInvalidInput
	}
	return s.store.SetAccountStatus(ctx, username, status)
}
func (s *Service) NewRecoveryCode(ctx context.Context, user User) (string, error) {
	code := randomText()
	if err := s.store.SetRecoveryHash(ctx, user.ID, tokenHash(code)); err != nil {
		return "", err
	}
	return code, nil
}
func (s *Service) ResetPassword(ctx context.Context, input PasswordResetInput) error {
	input.Username = normalizeUsername(input.Username)
	if !usernamePattern.MatchString(input.Username) || len(input.RecoveryCode) != 43 || !validPassword(input.Password) {
		return ErrCredentials
	}
	user, err := s.store.FindUser(ctx, input.Username)
	if err != nil {
		return ErrCredentials
	}
	if err := s.acquire(ctx); err != nil {
		return err
	}
	defer func() { <-s.semaphore }()
	hash, err := hashPassword(input.Password)
	if err != nil {
		return err
	}
	return s.store.ResetPassword(ctx, user.ID, tokenHash(input.RecoveryCode), hash)
}
func (s *Service) ResetAccountPassword(ctx context.Context, primary User, username, password string) error {
	if primary.Role != domain.RoleAdmin {
		return service.ErrForbidden
	}
	if !usernamePattern.MatchString(username) || !validPassword(password) {
		return service.ErrInvalidInput
	}
	user, err := s.store.FindUser(ctx, username)
	if err != nil {
		return err
	}

	if err := s.acquire(ctx); err != nil {
		return err
	}
	defer func() { <-s.semaphore }()
	hash, err := hashPassword(password)
	if err != nil {
		return err
	}
	return s.store.ResetPassword(ctx, user.ID, "", hash)
}

func (s *Service) ChangeOwnPassword(ctx context.Context, user User, currentPassword, password string) error {
	if !validPassword(password) || len(currentPassword) > 256 {
		return service.ErrInvalidInput
	}
	if err := s.acquire(ctx); err != nil {
		return err
	}
	defer func() { <-s.semaphore }()
	current, err := s.store.FindUser(ctx, user.Username)
	if err != nil {
		return err
	}
	if !verifyPassword(currentPassword, current.PasswordHash) {
		return ErrCredentials
	}
	hash, err := hashPassword(password)
	if err != nil {
		return err
	}
	// The expected password hash prevents a stale password change after another reset.
	return s.store.ResetPassword(ctx, user.ID, "password:"+current.PasswordHash, hash)
}
