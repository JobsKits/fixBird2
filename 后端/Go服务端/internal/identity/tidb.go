package identity

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/go-sql-driver/mysql"
	"repair-platform/internal/repository"
)

type TiDB struct{ db *sql.DB }

func NewTiDB(db *sql.DB) *TiDB { return &TiDB{db: db} }

func (s *TiDB) CreateUser(ctx context.Context, value User) error {
	if value.Status == "" {
		value.Status = "active"
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, "INSERT INTO repair_users (id, username, display_name, role, account_status, password_hash, recovery_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", value.ID, value.Username, value.DisplayName, value.Role, value.Status, value.PasswordHash, value.RecoveryHash, value.CreatedAt)
	var driverError *mysql.MySQLError
	if errors.As(err, &driverError) && driverError.Number == 1062 {
		return ErrUsernameTaken
	}
	return err
}

func (s *TiDB) FindUser(ctx context.Context, username string) (User, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var value User
	err := s.db.QueryRowContext(ctx, "SELECT id, username, display_name, role, account_status, password_hash, created_at FROM repair_users WHERE username = ?", username).Scan(&value.ID, &value.Username, &value.DisplayName, &value.Role, &value.Status, &value.PasswordHash, &value.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		err = repository.ErrNotFound
	}
	return value, err
}

func (s *TiDB) CreateSession(ctx context.Context, value Session) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := sessionCapacity(ctx, tx, value.UserID, value.CreatedAt); err != nil {
		return err
	}
	if value.ExpectedPasswordHash != "" {
		var current, status string
		if err := tx.QueryRowContext(ctx, "SELECT password_hash, account_status FROM repair_users WHERE id=?", value.UserID).Scan(&current, &status); err != nil {
			return err
		}
		if current != value.ExpectedPasswordHash || status != "active" {
			return ErrCredentials
		}
	}
	_, err = tx.ExecContext(ctx, "INSERT INTO repair_sessions (id, token_hash, user_id, expires_at, created_at, device_kind, device_label, device_platform, auth_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", value.ID, value.Hash, value.UserID, value.ExpiresAt, value.CreatedAt, value.Device.Kind, value.Device.Label, value.Device.Platform, value.AuthMethod)
	if err != nil {
		return authTransactionError(err)
	}
	return authTransactionError(tx.Commit())
}

func (s *TiDB) SessionUser(ctx context.Context, hash string, now time.Time) (User, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var value User
	var session Session
	err := s.db.QueryRowContext(ctx, "SELECT u.id, u.username, u.display_name, u.role, u.account_status, u.password_hash, u.created_at, s.id, s.device_kind, s.device_label, s.device_platform, s.auth_method, s.created_at, s.expires_at FROM repair_sessions s JOIN repair_users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > ?", hash, now).Scan(&value.ID, &value.Username, &value.DisplayName, &value.Role, &value.Status, &value.PasswordHash, &value.CreatedAt, &session.ID, &session.Device.Kind, &session.Device.Label, &session.Device.Platform, &session.AuthMethod, &session.CreatedAt, &session.ExpiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		err = ErrUnauthenticated
	}
	if err == nil {
		info := sessionInfo(session)
		info.IsCurrent = true
		value.Session = &info
	}
	return value, err
}

func (s *TiDB) RevokeSession(ctx context.Context, hash string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, "DELETE FROM repair_sessions WHERE token_hash = ?", hash)
	return err
}

func (s *TiDB) Ready(ctx context.Context) error {
	for _, query := range []string{"SELECT id, username, display_name, role, account_status, password_hash, recovery_hash, created_at, session_version FROM repair_users LIMIT 0", "SELECT id, token_hash, user_id, expires_at, created_at, device_kind, device_label, device_platform, auth_method FROM repair_sessions LIMIT 0", "SELECT id, poll_hash, approval_hash, device_label, device_platform, status, user_id, expires_at, created_at FROM repair_qr_challenges LIMIT 0", "SELECT id,version FROM repair_identity_locks WHERE id=1"} {
		rows, err := s.db.QueryContext(ctx, query)
		if err != nil {
			return err
		}
		if err := rows.Close(); err != nil {
			return err
		}
	}
	return nil
}
