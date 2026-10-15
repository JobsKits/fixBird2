package migration

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"sort"
	"time"
)

const metadataDDL = `CREATE TABLE IF NOT EXISTS repair_schema_migrations (
	version VARCHAR(255) PRIMARY KEY, checksum CHAR(64) NOT NULL,
	dirty BOOLEAN NOT NULL, applied_at TIMESTAMP(3) NULL
)`
const lockDDL = `CREATE TABLE IF NOT EXISTS repair_schema_lock (
	id TINYINT PRIMARY KEY, token VARCHAR(64) NOT NULL,
	expires_at DATETIME(3) NOT NULL
)`

var filePattern = regexp.MustCompile(`^\d{3}_[a-z0-9_]+\.sql$`)

type Step struct {
	Version, Checksum string
	Statements        []string
}

func Load(source fs.FS) ([]Step, error) {
	entries, err := fs.ReadDir(source, ".")
	if err != nil {
		return nil, err
	}
	var steps []Step
	for _, entry := range entries {
		if entry.IsDir() || !filePattern.MatchString(entry.Name()) {
			continue
		}
		payload, err := fs.ReadFile(source, entry.Name())
		if err != nil {
			return nil, err
		}
		statements, err := SplitSQL(string(payload))
		if err != nil {
			return nil, fmt.Errorf("%s: %w", entry.Name(), err)
		}
		hash := sha256.Sum256(payload)
		steps = append(steps, Step{Version: entry.Name(), Checksum: hex.EncodeToString(hash[:]), Statements: statements})
	}
	sort.Slice(steps, func(i, j int) bool { return steps[i].Version < steps[j].Version })
	if len(steps) == 0 {
		return nil, errors.New("no versioned SQL migrations found")
	}
	for i := 1; i < len(steps); i++ {
		if steps[i-1].Version[:3] == steps[i].Version[:3] {
			return nil, errors.New("duplicate migration version")
		}
	}
	return steps, nil
}

// Run marks DDL dirty before applying it: TiDB DDL cannot be rolled back as one transaction.
// A failed step is resumed only after explicitly naming it; all bundled steps are rerunnable.
func Run(ctx context.Context, db *sql.DB, source fs.FS, resume string) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	steps, err := Load(source)
	if err != nil {
		return err
	}
	if _, err := db.ExecContext(ctx, lockDDL); err != nil {
		return err
	}
	if _, err := db.ExecContext(ctx, metadataDDL); err != nil {
		return err
	}
	token, err := acquire(ctx, db)
	if err != nil {
		return err
	}
	defer func() {
		releaseCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_, _ = db.ExecContext(releaseCtx, "UPDATE repair_schema_lock SET token = '', expires_at = '1970-01-01 00:00:00' WHERE id = 1 AND token = ?", token)
	}()
	if resume != "" {
		known := false
		for _, step := range steps {
			if step.Version == resume {
				known = true
			}
		}
		if !known {
			return fmt.Errorf("unknown resume migration %q", resume)
		}
	}
	for _, step := range steps {
		var previous string
		var dirty bool
		err := db.QueryRowContext(ctx, "SELECT checksum, dirty FROM repair_schema_migrations WHERE version = ?", step.Version).Scan(&previous, &dirty)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return err
		}
		if err == nil {
			if previous != step.Checksum {
				return fmt.Errorf("migration %s checksum mismatch; restore the original file", step.Version)
			}
			if !dirty {
				continue
			}
			if resume != step.Version {
				return fmt.Errorf("migration %s is dirty; inspect schema then explicitly use -resume %s", step.Version, step.Version)
			}
		} else {
			if _, err := db.ExecContext(ctx, "INSERT INTO repair_schema_migrations (version, checksum, dirty) VALUES (?, ?, TRUE)", step.Version, step.Checksum); err != nil {
				return err
			}
		}
		for i, statement := range step.Statements {
			if err := renew(ctx, db, token); err != nil {
				return err
			}
			if _, err := db.ExecContext(ctx, statement); err != nil {
				return fmt.Errorf("migration %s statement %d: %w", step.Version, i+1, err)
			}
		}
		if _, err := db.ExecContext(ctx, "UPDATE repair_schema_migrations SET dirty = FALSE, applied_at = UTC_TIMESTAMP(3) WHERE version = ?", step.Version); err != nil {
			return err
		}
	}
	return nil
}

func acquire(ctx context.Context, db *sql.DB) (string, error) {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		return "", err
	}
	token := hex.EncodeToString(value)
	if _, err := db.ExecContext(ctx, "INSERT IGNORE INTO repair_schema_lock (id, token, expires_at) VALUES (1, '', '1970-01-01 00:00:00')"); err != nil {
		return "", err
	}
	for {
		result, err := db.ExecContext(ctx, "UPDATE repair_schema_lock SET token = ?, expires_at = DATE_ADD(UTC_TIMESTAMP(3), INTERVAL 5 MINUTE) WHERE id = 1 AND (token = '' OR expires_at < UTC_TIMESTAMP(3))", token)
		if err != nil {
			return "", err
		}
		count, err := result.RowsAffected()
		if err != nil {
			return "", err
		}
		if count == 1 {
			return token, nil
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(100 * time.Millisecond):
		}
	}
}

func renew(ctx context.Context, db *sql.DB, token string) error {
	result, err := db.ExecContext(ctx, "UPDATE repair_schema_lock SET expires_at = DATE_ADD(UTC_TIMESTAMP(3), INTERVAL 5 MINUTE) WHERE id = 1 AND token = ?", token)
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count != 1 {
		var current string
		if err := db.QueryRowContext(ctx, "SELECT token FROM repair_schema_lock WHERE id = 1").Scan(&current); err != nil {
			return err
		}
		if current != token {
			return errors.New("migration lock was lost")
		}
	}
	return nil
}

func Seed(ctx context.Context, db *sql.DB, source fs.FS, name string) error {
	payload, err := fs.ReadFile(source, path.Clean(name))
	if err != nil {
		return err
	}
	statements, err := SplitSQL(string(payload))
	if err != nil {
		return err
	}
	for _, statement := range statements {
		if _, err := db.ExecContext(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}
