package identity

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"repair-platform/internal/repository"
)

func (s *TiDB) ListSessions(ctx context.Context, userID string, now time.Time) ([]SessionInfo, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx, "SELECT id, device_kind, device_label, device_platform, auth_method, created_at, expires_at FROM repair_sessions WHERE user_id=? AND expires_at>? ORDER BY created_at DESC LIMIT 200", userID, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]SessionInfo, 0)
	for rows.Next() {
		var value Session
		if err := rows.Scan(&value.ID, &value.Device.Kind, &value.Device.Label, &value.Device.Platform, &value.AuthMethod, &value.CreatedAt, &value.ExpiresAt); err != nil {
			return nil, err
		}
		result = append(result, sessionInfo(value))
	}
	return result, rows.Err()
}
func (s *TiDB) RevokeDevice(ctx context.Context, userID, id string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	result, err := s.db.ExecContext(ctx, "DELETE FROM repair_sessions WHERE id=? AND user_id=?", id, userID)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return repository.ErrNotFound
	}
	return nil
}

const challengeColumns = "id, poll_hash, approval_hash, device_label, device_platform, status, user_id, expires_at, created_at"

func scanChallenge(row interface{ Scan(...any) error }) (Challenge, error) {
	var value Challenge
	value.Device.Kind = "desktop"
	err := row.Scan(&value.ID, &value.PollHash, &value.ApprovalHash, &value.Device.Label, &value.Device.Platform, &value.Status, &value.UserID, &value.ExpiresAt, &value.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		err = repository.ErrNotFound
	}
	return value, err
}
func (s *TiDB) CreateChallenge(ctx context.Context, value Challenge) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var lockID int
	if err := tx.QueryRowContext(ctx, "SELECT id FROM repair_identity_locks WHERE id=1 FOR UPDATE").Scan(&lockID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE repair_identity_locks SET version=version+1 WHERE id=1"); err != nil {
		return authTransactionError(err)
	}
	if _, err := tx.ExecContext(ctx, "DELETE FROM repair_qr_challenges WHERE expires_at < ?", value.CreatedAt.Add(-5*time.Minute)); err != nil {
		return err
	}
	var count int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_qr_challenges").Scan(&count); err != nil {
		return err
	}
	if count >= 1000 {
		return ErrRateLimited
	}
	_, err = tx.ExecContext(ctx, "INSERT INTO repair_qr_challenges ("+challengeColumns+") VALUES (?, ?, ?, ?, ?, ?, '', ?, ?)", value.ID, value.PollHash, value.ApprovalHash, value.Device.Label, value.Device.Platform, value.Status, value.ExpiresAt, value.CreatedAt)
	if err != nil {
		return authTransactionError(err)
	}
	return authTransactionError(tx.Commit())
}
func (s *TiDB) GetChallenge(ctx context.Context, id string) (Challenge, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return scanChallenge(s.db.QueryRowContext(ctx, "SELECT "+challengeColumns+" FROM repair_qr_challenges WHERE id=?", id))
}
func (s *TiDB) ApproveChallenge(ctx context.Context, id, hash, userID, decision string, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	value, err := scanChallenge(tx.QueryRowContext(ctx, "SELECT "+challengeColumns+" FROM repair_qr_challenges WHERE id=? FOR UPDATE", id))
	if err != nil {
		return err
	}
	if !equalHash(value.ApprovalHash, hash) {
		return ErrUnauthenticated
	}
	if !value.ExpiresAt.After(now) || value.Status != "pending" {
		return repository.ErrInvalidState
	}
	status := "approved"
	if decision == "reject" {
		status = "rejected"
	}
	if _, err := tx.ExecContext(ctx, "UPDATE repair_qr_challenges SET status=?, user_id=? WHERE id=?", status, userID, id); err != nil {
		return err
	}
	return tx.Commit()
}
func (s *TiDB) RedeemChallenge(ctx context.Context, id, hash string, session Session, now time.Time) (User, string, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return User{}, "", err
	}
	defer tx.Rollback()
	value, err := scanChallenge(tx.QueryRowContext(ctx, "SELECT "+challengeColumns+" FROM repair_qr_challenges WHERE id=? FOR UPDATE", id))
	if err != nil {
		return User{}, "", err
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
	var user User
	if err := tx.QueryRowContext(ctx, "SELECT id, username, display_name, role, account_status, password_hash, created_at FROM repair_users WHERE id=?", value.UserID).Scan(&user.ID, &user.Username, &user.DisplayName, &user.Role, &user.Status, &user.PasswordHash, &user.CreatedAt); err != nil {
		return User{}, "", err
	}
	session.Device = value.Device
	session.Device.Kind = "desktop"
	session.AuthMethod = "qr"
	session.UserID = user.ID
	if err := sessionCapacity(ctx, tx, user.ID, now); err != nil {
		return User{}, "", err
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO repair_sessions (id, token_hash, user_id, expires_at, created_at, device_kind, device_label, device_platform, auth_method) VALUES (?, ?, ?, ?, ?, 'desktop', ?, ?, 'qr')", session.ID, session.Hash, session.UserID, session.ExpiresAt, session.CreatedAt, session.Device.Label, session.Device.Platform); err != nil {
		return User{}, "", err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE repair_qr_challenges SET status='consumed' WHERE id=?", id); err != nil {
		return User{}, "", err
	}
	if err := tx.Commit(); err != nil {
		return User{}, "", authTransactionError(err)
	}
	info := sessionInfo(session)
	info.IsCurrent = true
	user.Session = &info
	return user, "approved", nil
}
