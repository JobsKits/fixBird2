package identity

import (
	"context"
	"database/sql"
	"errors"
	"repair-platform/internal/repository"
	"strings"
	"time"
)

func (s *TiDB) ListAccounts(ctx context.Context, after string) ([]User, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx, "SELECT id, username, display_name, role, account_status, created_at FROM repair_users WHERE username>? ORDER BY username LIMIT 51", after)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	values := make([]User, 0)
	for rows.Next() {
		var user User
		if err := rows.Scan(&user.ID, &user.Username, &user.DisplayName, &user.Role, &user.Status, &user.CreatedAt); err != nil {
			return nil, err
		}
		values = append(values, user)
	}
	return values, rows.Err()
}
func (s *TiDB) SetAccountStatus(ctx context.Context, username, status string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var id string
	if err := tx.QueryRowContext(ctx, "SELECT id FROM repair_users WHERE username=? FOR UPDATE", username).Scan(&id); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE repair_users SET account_status=?, session_version=session_version+1 WHERE id=?", status, id); err != nil {
		return authTransactionError(err)
	}
	if status == "disabled" {
		if _, err := tx.ExecContext(ctx, "DELETE FROM repair_sessions WHERE user_id=?", id); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM repair_qr_challenges WHERE user_id=?", id); err != nil {
			return err
		}
	}
	return authTransactionError(tx.Commit())
}
func (s *TiDB) SetRecoveryHash(ctx context.Context, id, hash string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	result, err := s.db.ExecContext(ctx, "UPDATE repair_users SET recovery_hash=? WHERE id=?", hash, id)
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count != 1 {
		return repository.ErrNotFound
	}
	return nil
}
func (s *TiDB) ResetPassword(ctx context.Context, id, expected, passwordHash string) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var current, currentPassword string
	if err := tx.QueryRowContext(ctx, "SELECT recovery_hash, password_hash FROM repair_users WHERE id=? FOR UPDATE", id).Scan(&current, &currentPassword); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrCredentials
		}
		return err
	}
	if strings.HasPrefix(expected, "password:") {
		if currentPassword != strings.TrimPrefix(expected, "password:") {
			return ErrCredentials
		}
	} else if expected != "" && (current == "" || !equalHash(current, expected)) {
		return ErrCredentials
	}
	// The user version also serializes optimistic transactions against concurrent login/reset.
	if _, err = tx.ExecContext(ctx, "UPDATE repair_users SET password_hash=?, recovery_hash='', session_version=session_version+1 WHERE id=?", passwordHash, id); err != nil {
		return authTransactionError(err)
	}
	if _, err = tx.ExecContext(ctx, "DELETE FROM repair_sessions WHERE user_id=?", id); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, "DELETE FROM repair_qr_challenges WHERE user_id=?", id); err != nil {
		return err
	}
	return authTransactionError(tx.Commit())
}
