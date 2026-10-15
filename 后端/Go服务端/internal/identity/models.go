package identity

import (
	"errors"
	"repair-platform/internal/domain"
	"time"
)

var (
	ErrUnauthenticated = errors.New("valid session is required")
	ErrCredentials     = errors.New("username or password is incorrect")
	ErrUsernameTaken   = errors.New("username is already registered")
	ErrAccountDisabled = errors.New("account is disabled")
	ErrRateLimited     = errors.New("too many authentication attempts")
)

type User struct {
	ID           string       `json:"id"`
	Username     string       `json:"username"`
	DisplayName  string       `json:"displayName"`
	Role         domain.Role  `json:"role"`
	Status       string       `json:"status"`
	RecoveryHash string       `json:"-"`
	PasswordHash string       `json:"-"`
	CreatedAt    time.Time    `json:"-"`
	Session      *SessionInfo `json:"session,omitempty"`
}

func (u User) Actor() domain.Actor { return domain.Actor{ID: u.ID, Role: u.Role} }

type Session struct {
	ExpectedPasswordHash string
	ID                   string
	Device               Device
	AuthMethod           string
	Hash                 string
	UserID               string
	ExpiresAt            time.Time
	CreatedAt            time.Time
}
type Result struct {
	Token     string      `json:"token"`
	ExpiresAt time.Time   `json:"expiresAt"`
	User      User        `json:"user"`
	Session   SessionInfo `json:"session"`
}
type RegisterInput struct {
	Username    string      `json:"username"`
	Password    string      `json:"password"`
	DisplayName string      `json:"displayName"`
	Role        domain.Role `json:"role"`
	Device      Device      `json:"device"`
}
type LoginInput struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Device   Device `json:"device"`
}

type Device struct {
	Kind     string `json:"kind"`
	Label    string `json:"label"`
	Platform string `json:"platform"`
}
type SessionInfo struct {
	ID           string    `json:"id"`
	Device       Device    `json:"device"`
	AuthMethod   string    `json:"authMethod"`
	Capabilities []string  `json:"capabilities"`
	CreatedAt    time.Time `json:"createdAt"`
	ExpiresAt    time.Time `json:"expiresAt"`
	IsCurrent    bool      `json:"isCurrent"`
}

func sessionInfo(s Session) SessionInfo {
	capabilities := make([]string, 0)
	if s.AuthMethod == "password" && s.Device.Kind == "mobile" {
		capabilities = []string{"manage_devices", "authorize_qr"}
	}
	return SessionInfo{ID: s.ID, Device: s.Device, AuthMethod: s.AuthMethod, Capabilities: capabilities, CreatedAt: s.CreatedAt, ExpiresAt: s.ExpiresAt}
}

type Challenge struct {
	ID           string    `json:"id"`
	Device       Device    `json:"device"`
	Status       string    `json:"status"`
	ExpiresAt    time.Time `json:"expiresAt"`
	CreatedAt    time.Time `json:"-"`
	PollHash     string    `json:"-"`
	ApprovalHash string    `json:"-"`
	UserID       string    `json:"-"`
}
type ChallengeResult struct {
	Challenge
	PollToken string `json:"pollToken"`
	QRPayload string `json:"qrPayload"`
}
type PollResult struct {
	Status string  `json:"status"`
	Auth   *Result `json:"auth,omitempty"`
}
