package workers

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/go-sql-driver/mysql"
	"repair-platform/internal/repository"
)

type TiDB struct{ db *sql.DB }

func NewTiDB(db *sql.DB) *TiDB { return &TiDB{db: db} }

const applicationColumns = "id, worker_id, display_name, contact_phone, service_areas, skills, bio, asset_ids, status, revision, review_note, reviewed_by, reviewed_at, created_at, updated_at"

type scanner interface{ Scan(...any) error }

func scanApplication(row scanner) (Application, error) {
	var a Application
	var areas, skills, assets []byte
	var reviewed sql.NullTime
	err := row.Scan(&a.ID, &a.WorkerID, &a.DisplayName, &a.ContactPhone, &areas, &skills, &a.Bio, &assets, &a.Status, &a.Revision, &a.ReviewNote, &a.ReviewedBy, &reviewed, &a.CreatedAt, &a.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Application{}, repository.ErrNotFound
	}
	if err != nil {
		return Application{}, err
	}
	if reviewed.Valid {
		a.ReviewedAt = &reviewed.Time
	}
	for _, entry := range []struct {
		raw    []byte
		target *[]string
	}{{areas, &a.ServiceAreas}, {skills, &a.Skills}, {assets, &a.AssetIDs}} {
		if err := json.Unmarshal(entry.raw, entry.target); err != nil {
			return Application{}, err
		}
	}
	return a, nil
}

func (s *TiDB) GetApplication(ctx context.Context, id string) (Application, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return scanApplication(s.db.QueryRowContext(ctx, "SELECT "+applicationColumns+" FROM repair_worker_applications WHERE worker_id = ?", id))
}

func updateRoster(ctx context.Context, tx *sql.Tx, a Application) error {
	areas, _ := json.Marshal(a.ServiceAreas)
	skills, _ := json.Marshal(a.Skills)
	_, err := tx.ExecContext(ctx, "INSERT INTO repair_workers (id, display_name, service_areas, skills, status) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), service_areas = VALUES(service_areas), skills = VALUES(skills), status = VALUES(status)", a.WorkerID, a.DisplayName, areas, skills, a.Status)
	return err
}

func transactionError(err error) error {
	var driverError *mysql.MySQLError
	if errors.As(err, &driverError) && (driverError.Number == 1062 || driverError.Number == 9007 || driverError.Number == 1213 || driverError.Number == 1205) {
		return ErrRevisionConflict
	}
	return err
}

func (s *TiDB) Submit(ctx context.Context, a Application, expected int64) (Application, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Application{}, err
	}
	defer tx.Rollback()
	current, err := scanApplication(tx.QueryRowContext(ctx, "SELECT "+applicationColumns+" FROM repair_worker_applications WHERE worker_id = ? FOR UPDATE", a.WorkerID))
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return Application{}, err
	}
	exists := err == nil
	if (!exists && expected != 0) || (exists && current.Revision != expected) {
		return Application{}, ErrRevisionConflict
	}
	if exists {
		a.ID = current.ID
		a.CreatedAt = current.CreatedAt
	}
	a.Revision = expected + 1
	a.Status = "pending"
	areas, _ := json.Marshal(a.ServiceAreas)
	skills, _ := json.Marshal(a.Skills)
	assets, _ := json.Marshal(a.AssetIDs)
	if exists {
		_, err = tx.ExecContext(ctx, "UPDATE repair_worker_applications SET display_name=?, contact_phone=?, service_areas=?, skills=?, bio=?, asset_ids=?, status='pending', revision=?, review_note='', reviewed_by='', reviewed_at=NULL, updated_at=? WHERE id=?", a.DisplayName, a.ContactPhone, areas, skills, a.Bio, assets, a.Revision, a.UpdatedAt, a.ID)
	} else {
		_, err = tx.ExecContext(ctx, "INSERT INTO repair_worker_applications ("+applicationColumns+") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', '', NULL, ?, ?)", a.ID, a.WorkerID, a.DisplayName, a.ContactPhone, areas, skills, a.Bio, assets, a.Status, a.Revision, a.CreatedAt, a.UpdatedAt)
	}
	if err != nil {
		return Application{}, transactionError(err)
	}
	if err := updateRoster(ctx, tx, a); err != nil {
		return Application{}, transactionError(err)
	}
	if err := tx.Commit(); err != nil {
		return Application{}, transactionError(err)
	}
	return a, nil
}

func (s *TiDB) Review(ctx context.Context, id string, input ReviewInput, actorID string, now time.Time) (Application, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Application{}, err
	}
	defer tx.Rollback()
	a, err := scanApplication(tx.QueryRowContext(ctx, "SELECT "+applicationColumns+" FROM repair_worker_applications WHERE id = ? FOR UPDATE", id))
	if err != nil {
		return Application{}, err
	}
	if a.Revision != input.ExpectedRevision {
		return Application{}, ErrRevisionConflict
	}
	if a.Status != "pending" {
		return Application{}, repository.ErrInvalidState
	}
	a.Status = input.Decision
	a.ReviewNote = input.Note
	a.ReviewedBy = actorID
	a.ReviewedAt = &now
	a.UpdatedAt = now
	_, err = tx.ExecContext(ctx, "UPDATE repair_worker_applications SET status=?, review_note=?, reviewed_by=?, reviewed_at=?, updated_at=? WHERE id=?", a.Status, a.ReviewNote, a.ReviewedBy, now, now, a.ID)
	if err != nil {
		return Application{}, transactionError(err)
	}
	if err := updateRoster(ctx, tx, a); err != nil {
		return Application{}, transactionError(err)
	}
	if err := tx.Commit(); err != nil {
		return Application{}, transactionError(err)
	}
	return a, nil
}

func (s *TiDB) List(ctx context.Context, q ListQuery) ([]Application, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	query := "SELECT " + applicationColumns + " FROM repair_worker_applications WHERE 1=1"
	args := make([]any, 0)
	if q.Status != "" {
		query += " AND status=?"
		args = append(args, q.Status)
	}
	if q.Before != nil {
		query += " AND (created_at < ? OR (created_at = ? AND id < ?))"
		args = append(args, q.Before.CreatedAt, q.Before.CreatedAt, q.Before.ID)
	}
	query += " ORDER BY created_at DESC, id DESC LIMIT ?"
	args = append(args, q.Limit+1)
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]Application, 0)
	for rows.Next() {
		a, err := scanApplication(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, a)
	}
	return result, rows.Err()
}

func (s *TiDB) SaveAsset(ctx context.Context, a Asset) error {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, "INSERT INTO repair_worker_assets (id, owner_id, mime_type, size_bytes, created_at) VALUES (?, ?, ?, ?, ?)", a.ID, a.OwnerID, a.MIMEType, a.SizeBytes, a.CreatedAt)
	return err
}
func (s *TiDB) GetAsset(ctx context.Context, id string) (Asset, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var a Asset
	err := s.db.QueryRowContext(ctx, "SELECT id, owner_id, mime_type, size_bytes, created_at FROM repair_worker_assets WHERE id = ?", id).Scan(&a.ID, &a.OwnerID, &a.MIMEType, &a.SizeBytes, &a.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		err = repository.ErrNotFound
	}
	return a, err
}
func (s *TiDB) CanAccept(ctx context.Context, id string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var status string
	err := s.db.QueryRowContext(ctx, "SELECT status FROM repair_workers WHERE id = ?", id).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return status == "approved", err
}
func (s *TiDB) Ready(ctx context.Context) error {
	for _, query := range []string{"SELECT " + applicationColumns + " FROM repair_worker_applications LIMIT 0", "SELECT id, owner_id, mime_type, size_bytes, created_at FROM repair_worker_assets LIMIT 0", "SELECT id,qualification_version FROM repair_workers LIMIT 0"} {
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
