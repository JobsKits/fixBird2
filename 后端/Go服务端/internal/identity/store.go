package identity

import (
	"context"
	"repair-platform/internal/repository"
	"sync"
	"time"
)

type Store interface {
	CreateUser(context.Context, User) error
	FindUser(context.Context, string) (User, error)
	CreateSession(context.Context, Session) error
	SessionUser(context.Context, string, time.Time) (User, error)
	RevokeSession(context.Context, string) error
	Ready(context.Context) error
	ListAccounts(context.Context, string) ([]User, error)
	SetAccountStatus(context.Context, string, string) error
	SetRecoveryHash(context.Context, string, string) error
	ResetPassword(context.Context, string, string, string) error
	ListSessions(context.Context, string, time.Time) ([]SessionInfo, error)
	RevokeDevice(context.Context, string, string) error
	CreateChallenge(context.Context, Challenge) error
	GetChallenge(context.Context, string) (Challenge, error)
	ApproveChallenge(context.Context, string, string, string, string, time.Time) error
	RedeemChallenge(context.Context, string, string, Session, time.Time) (User, string, error)
}

type Memory struct {
	mu         sync.RWMutex
	users      map[string]User
	sessions   map[string]Session
	challenges map[string]Challenge
}

func NewMemory() *Memory {
	return &Memory{users: make(map[string]User), sessions: make(map[string]Session), challenges: make(map[string]Challenge)}
}
func (s *Memory) Ready(ctx context.Context) error { return ctx.Err() }
func (s *Memory) CreateUser(ctx context.Context, value User) error {
	if value.Status == "" {
		value.Status = "active"
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.users[value.Username]; exists {
		return ErrUsernameTaken
	}
	s.users[value.Username] = value
	return nil
}
func (s *Memory) FindUser(ctx context.Context, username string) (User, error) {
	if err := ctx.Err(); err != nil {
		return User{}, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	value, exists := s.users[username]
	if !exists {
		return User{}, repository.ErrNotFound
	}
	return value, nil
}
func (s *Memory) CreateSession(ctx context.Context, value Session) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for key, current := range s.sessions {
		if !current.ExpiresAt.After(value.CreatedAt) {
			delete(s.sessions, key)
		}
	}
	count := 0
	for _, current := range s.sessions {
		if current.UserID == value.UserID {
			count++
		}
	}
	if count >= 50 {
		return ErrRateLimited
	}
	if value.ExpectedPasswordHash != "" {
		valid := false
		for _, user := range s.users {
			if user.ID == value.UserID && (user.Status == "" || user.Status == "active") && user.PasswordHash == value.ExpectedPasswordHash {
				valid = true
			}
		}
		if !valid {
			return ErrCredentials
		}
	}
	s.sessions[value.Hash] = value
	return nil
}
func (s *Memory) SessionUser(ctx context.Context, hash string, now time.Time) (User, error) {
	if err := ctx.Err(); err != nil {
		return User{}, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	value, exists := s.sessions[hash]
	if !exists || !value.ExpiresAt.After(now) {
		return User{}, ErrUnauthenticated
	}
	for _, user := range s.users {
		if user.ID == value.UserID {
			info := sessionInfo(value)
			info.IsCurrent = true
			user.Session = &info
			return user, nil
		}
	}
	return User{}, ErrUnauthenticated
}
func (s *Memory) RevokeSession(ctx context.Context, hash string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.sessions, hash)
	return nil
}
