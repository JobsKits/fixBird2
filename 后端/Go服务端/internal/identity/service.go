package identity

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"repair-platform/internal/domain"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
)

type attempt struct {
	Count int
	Until time.Time
}
type Service struct {
	store     Store
	ttl       time.Duration
	dummyHash string
	semaphore chan struct{}
	mu        sync.Mutex
	attempts  map[string]attempt
}

func NewService(store Store, ttl time.Duration) (*Service, error) {
	if ttl < time.Minute || ttl > 7*24*time.Hour {
		return nil, service.ErrInvalidInput
	}
	dummy, err := hashPassword("unused-" + randomText())
	if err != nil {
		return nil, err
	}
	return &Service{store: store, ttl: ttl, dummyHash: dummy, semaphore: make(chan struct{}, 2), attempts: make(map[string]attempt)}, nil
}

func randomText() string {
	value := make([]byte, 32)
	_, _ = rand.Read(value)
	return base64.RawURLEncoding.EncodeToString(value)
}
func tokenHash(token string) string {
	value := sha256.Sum256([]byte(token))
	return hex.EncodeToString(value[:])
}
func normalizeUsername(value string) string { return strings.ToLower(strings.TrimSpace(value)) }

var usernamePattern = regexp.MustCompile(`^[a-z0-9_.-]{3,64}$`)

func validPassword(value string) bool {
	return utf8.ValidString(value) && utf8.RuneCountInString(value) >= 12 && utf8.RuneCountInString(value) <= 128 && len(value) <= 256
}

func (s *Service) acquire(ctx context.Context) error {
	select {
	case s.semaphore <- struct{}{}:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *Service) AllowAttempt(key string) bool {
	return s.AllowAttemptLimit(key, 10)
}

func (s *Service) AllowAttemptLimit(key string, limit int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for name, value := range s.attempts {
		if !value.Until.After(now) {
			delete(s.attempts, name)
		}
	}
	value, exists := s.attempts[key]
	if !exists {
		if len(s.attempts) >= 4096 {
			return false
		}
		value = attempt{Until: now.Add(time.Minute)}
	}
	value.Count++
	s.attempts[key] = value
	return value.Count <= limit
}

func (s *Service) createSession(ctx context.Context, user User, device Device) (Result, error) {
	token := randomText()
	now := time.Now().UTC().Truncate(time.Millisecond)
	expires := now.Add(s.ttl)
	value := Session{ExpectedPasswordHash: user.PasswordHash, ID: "dev_" + randomText()[:32], Device: device, AuthMethod: "password", Hash: tokenHash(token), UserID: user.ID, CreatedAt: now, ExpiresAt: expires}
	if err := s.store.CreateSession(ctx, value); err != nil {
		return Result{}, err
	}
	info := sessionInfo(value)
	info.IsCurrent = true
	user.Session = &info
	return Result{Token: token, ExpiresAt: expires, User: user, Session: info}, nil
}

func (s *Service) Register(ctx context.Context, input RegisterInput) (Result, error) {
	device, deviceErr := normalizeDevice(input.Device, false)
	if deviceErr != nil {
		return Result{}, deviceErr
	}
	input.Username = normalizeUsername(input.Username)
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	if input.Username == "admin" || !usernamePattern.MatchString(input.Username) || !validPassword(input.Password) || !utf8.ValidString(input.DisplayName) || input.DisplayName == "" || utf8.RuneCountInString(input.DisplayName) > 120 || (input.Role != domain.RoleCustomer && input.Role != domain.RoleWorker) {
		return Result{}, service.ErrInvalidInput
	}
	if err := s.acquire(ctx); err != nil {
		return Result{}, err
	}
	defer func() { <-s.semaphore }()
	hash, err := hashPassword(input.Password)
	if err != nil {
		return Result{}, err
	}
	user := User{ID: "usr_" + randomText()[:32], Username: input.Username, DisplayName: input.DisplayName, Role: input.Role, Status: "active", PasswordHash: hash, CreatedAt: time.Now().UTC().Truncate(time.Millisecond)}
	if err := s.store.CreateUser(ctx, user); err != nil {
		return Result{}, err
	}
	return s.createSession(ctx, user, device)
}

func (s *Service) Login(ctx context.Context, input LoginInput) (Result, error) {
	device, deviceErr := normalizeDevice(input.Device, false)
	if deviceErr != nil {
		return Result{}, deviceErr
	}
	input.Username = normalizeUsername(input.Username)
	if !usernamePattern.MatchString(input.Username) || len(input.Password) > 256 {
		return Result{}, ErrCredentials
	}
	if err := s.acquire(ctx); err != nil {
		return Result{}, err
	}
	defer func() { <-s.semaphore }()
	user, err := s.store.FindUser(ctx, input.Username)
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return Result{}, err
	}
	hash := user.PasswordHash
	if errors.Is(err, repository.ErrNotFound) {
		hash = s.dummyHash
	}
	valid := verifyPassword(input.Password, hash)
	if !valid || err != nil {
		return Result{}, ErrCredentials
	}
	if user.Status != "" && user.Status != "active" {
		return Result{}, ErrAccountDisabled
	}
	return s.createSession(ctx, user, device)
}

func (s *Service) Authenticate(ctx context.Context, token string) (User, error) {
	if len(token) != 43 {
		return User{}, ErrUnauthenticated
	}
	value, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil || len(value) != 32 {
		return User{}, ErrUnauthenticated
	}
	user, err := s.store.SessionUser(ctx, tokenHash(token), time.Now().UTC())
	if err == nil && user.Status != "" && user.Status != "active" {
		return User{}, ErrUnauthenticated
	}
	return user, err
}

func (s *Service) Logout(ctx context.Context, token string) error {
	return s.store.RevokeSession(ctx, tokenHash(token))
}
func (s *Service) Ready(ctx context.Context) error { return s.store.Ready(ctx) }

func (s *Service) BootstrapAdmin(ctx context.Context, username, password string) error {
	if username == "" && password == "" {
		username, password = "admin", "admin"
	}
	username = normalizeUsername(username)
	if !usernamePattern.MatchString(username) || (!validPassword(password) && !(username == "admin" && password == "admin")) {
		return service.ErrInvalidInput
	}
	existing, err := s.store.FindUser(ctx, username)
	if err == nil {
		if existing.Role != domain.RoleAdmin {
			return service.ErrForbidden
		}
		return nil
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return err
	}
	hash, err := hashPassword(password)
	if err != nil {
		return err
	}
	err = s.store.CreateUser(ctx, User{ID: "usr_" + randomText()[:32], Username: username, DisplayName: "平台管理员", Role: domain.RoleAdmin, Status: "active", PasswordHash: hash, CreatedAt: time.Now().UTC().Truncate(time.Millisecond)})
	if errors.Is(err, ErrUsernameTaken) {
		current, lookupErr := s.store.FindUser(ctx, username)
		if lookupErr == nil && current.Role == domain.RoleAdmin {
			return nil
		}
	}
	return err
}
