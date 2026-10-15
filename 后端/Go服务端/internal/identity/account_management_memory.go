package identity

import (
	"context"
	"repair-platform/internal/repository"
	"sort"
	"strings"
)

func (s *Memory) ListAccounts(ctx context.Context, after string) ([]User, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	values := make([]User, 0)
	for _, user := range s.users {
		if user.Username > after {
			values = append(values, user)
		}
	}
	sort.Slice(values, func(i, j int) bool { return values[i].Username < values[j].Username })
	if len(values) > 51 {
		values = values[:51]
	}
	return values, nil
}
func (s *Memory) SetAccountStatus(ctx context.Context, username, status string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	user, ok := s.users[username]
	if !ok {
		return repository.ErrNotFound
	}

	user.Status = status
	s.users[username] = user
	if status == "disabled" {
		for hash, session := range s.sessions {
			if session.UserID == user.ID {
				delete(s.sessions, hash)
			}
		}
		for key, challenge := range s.challenges {
			if challenge.UserID == user.ID {
				delete(s.challenges, key)
			}
		}
	}
	return nil
}
func (s *Memory) SetRecoveryHash(ctx context.Context, id, hash string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for username, user := range s.users {
		if user.ID == id {
			user.RecoveryHash = hash
			s.users[username] = user
			return nil
		}
	}
	return repository.ErrNotFound
}
func (s *Memory) ResetPassword(ctx context.Context, id, expected, passwordHash string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for username, user := range s.users {
		if user.ID != id {
			continue
		}
		if strings.HasPrefix(expected, "password:") {
			if user.PasswordHash != strings.TrimPrefix(expected, "password:") {
				return ErrCredentials
			}
		} else if expected != "" && (user.RecoveryHash == "" || !equalHash(user.RecoveryHash, expected)) {
			return ErrCredentials
		}
		user.PasswordHash, user.RecoveryHash = passwordHash, ""
		s.users[username] = user
		for hash, session := range s.sessions {
			if session.UserID == id {
				delete(s.sessions, hash)
			}
		}
		for key, challenge := range s.challenges {
			if challenge.UserID == id {
				delete(s.challenges, key)
			}
		}
		return nil
	}
	return ErrCredentials
}
