package identity

import (
	"context"
	"database/sql"
	"errors"
	"github.com/go-sql-driver/mysql"
	"repair-platform/internal/repository"
	"time"
)

func authTransactionError(err error) error {
	var driverError *mysql.MySQLError
	if errors.As(err, &driverError) && (driverError.Number == 9007 || driverError.Number == 1213 || driverError.Number == 1205 || driverError.Number == 1062) {
		return repository.ErrRetryable
	}
	return err
}

func sessionCapacity(ctx context.Context, tx *sql.Tx, userID string, now time.Time) error {
	var lockedID string
	if err := tx.QueryRowContext(ctx, "SELECT id FROM repair_users WHERE id=? FOR UPDATE", userID).Scan(&lockedID); err != nil {
		return err
	}
	// Touch a version row so optimistic TiDB transactions also enforce the session cap.
	if _, err := tx.ExecContext(ctx, "UPDATE repair_users SET session_version=session_version+1 WHERE id=?", userID); err != nil {
		return authTransactionError(err)
	}
	if _, err := tx.ExecContext(ctx, "DELETE FROM repair_sessions WHERE user_id=? AND expires_at<=?", userID, now); err != nil {
		return authTransactionError(err)
	}
	var count int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_sessions WHERE user_id=?", userID).Scan(&count); err != nil {
		return err
	}
	if count >= 50 {
		return ErrRateLimited
	}
	return nil
}
