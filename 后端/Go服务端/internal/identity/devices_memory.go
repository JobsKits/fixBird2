package identity

import (
	"context"
	"crypto/subtle"
	"repair-platform/internal/repository"
	"sort"
	"time"
)

func equalHash(a, b string) bool {
	return len(a) == 64 && len(b) == 64 && subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

func (s *Memory) ListSessions(ctx context.Context, userID string, now time.Time) ([]SessionInfo, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]SessionInfo, 0)
	for _, value := range s.sessions {
		if value.UserID == userID && value.ExpiresAt.After(now) {
			result = append(result, sessionInfo(value))
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].CreatedAt.After(result[j].CreatedAt) })
	return result, nil
}

func (s *Memory) RevokeDevice(ctx context.Context, userID, id string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for key, value := range s.sessions {
		if value.ID == id && value.UserID == userID {
			delete(s.sessions, key)
			return nil
		}
	}
	return repository.ErrNotFound
}

func (s *Memory) CreateChallenge(ctx context.Context, value Challenge) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for key, current := range s.challenges {
		if current.ExpiresAt.Before(value.CreatedAt.Add(-5 * time.Minute)) {
			delete(s.challenges, key)
		}
	}
	if len(s.challenges) >= 1000 {
		return ErrRateLimited
	}
	s.challenges[value.ID] = value
	return nil
}
func (s *Memory) GetChallenge(ctx context.Context, id string) (Challenge, error) {
	if err := ctx.Err(); err != nil {
		return Challenge{}, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	value, ok := s.challenges[id]
	if !ok {
		return Challenge{}, repository.ErrNotFound
	}
	return value, nil
}
func (s *Memory) ApproveChallenge(ctx context.Context, id, hash, userID, decision string, now time.Time) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	value, ok := s.challenges[id]
	if !ok {
		return repository.ErrNotFound
	}
	if !equalHash(value.ApprovalHash, hash) {
		return ErrUnauthenticated
	}
	if !value.ExpiresAt.After(now) || value.Status != "pending" {
		return repository.ErrInvalidState
	}
	value.Status = "approved"
	if decision == "reject" {
		value.Status = "rejected"
	}
	value.UserID = userID
	s.challenges[id] = value
	return nil
}
func (s *Memory) RedeemChallenge(ctx context.Context, id, hash string, session Session, now time.Time) (User, string, error) {
	if err := ctx.Err(); err != nil {
		return User{}, "", err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	value, ok := s.challenges[id]
	if !ok {
		return User{}, "", repository.ErrNotFound
	}
	if !equalHash(value.PollHash, hash) {
		return User{}, "", ErrUnauthenticated
	}
	if !value.ExpiresAt.After(now) {
		return User{}, "expired", nil
	}
	if value.Status != "approved" {
		return User{}, value.Status, nil
	}
	for _, user := range s.users {
		if user.ID == value.UserID {
			count := 0
			for key, current := range s.sessions {
				if !current.ExpiresAt.After(now) {
					delete(s.sessions, key)
				} else if current.UserID == user.ID {
					count++
				}
			}
			if count >= 50 {
				return User{}, "", ErrRateLimited
			}
			session.UserID = user.ID
			session.Device = value.Device
			session.Device.Kind = "desktop"
			session.AuthMethod = "qr"
			s.sessions[session.Hash] = session
			value.Status = "consumed"
			s.challenges[id] = value
			info := sessionInfo(session)
			info.IsCurrent = true
			user.Session = &info
			return user, "approved", nil
		}
	}
	return User{}, "", ErrUnauthenticated
}
