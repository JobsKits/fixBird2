package workbench

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"testing"
)

type clearFixture struct {
	key, encrypted                         []byte
	revision, affected                     int64
	empty, queryFail, execFail, commitFail bool
	committed, rolledBack, deleted         bool
	changeAfterLoad                        bool
}
type clearConnector struct{ fixture *clearFixture }
type clearDriver struct{}
type clearConnection struct{ fixture *clearFixture }
type clearTransaction struct{ fixture *clearFixture }
type clearRows struct {
	fixture  *clearFixture
	read     bool
	unlocked bool
}

func (c clearConnector) Connect(context.Context) (driver.Conn, error) {
	return &clearConnection{c.fixture}, nil
}
func (c clearConnector) Driver() driver.Driver       { return clearDriver{} }
func (clearDriver) Open(string) (driver.Conn, error) { return nil, errors.New("use connector") }
func (*clearConnection) Prepare(string) (driver.Stmt, error) {
	return nil, errors.New("no prepared statements")
}
func (*clearConnection) Close() error                { return nil }
func (c *clearConnection) Begin() (driver.Tx, error) { return &clearTransaction{c.fixture}, nil }
func (c *clearConnection) BeginTx(context.Context, driver.TxOptions) (driver.Tx, error) {
	return c.Begin()
}
func (c *clearConnection) QueryContext(_ context.Context, query string, _ []driver.NamedValue) (driver.Rows, error) {
	if query != "SELECT revision,payload FROM v38_workbench_snapshot WHERE id=1 FOR UPDATE" && query != "SELECT revision,payload FROM v38_workbench_snapshot WHERE id=1" {
		return nil, errors.New("query must lock only application id1")
	}
	if c.fixture.queryFail {
		return nil, errors.New("read failed")
	}
	return &clearRows{fixture: c.fixture, unlocked: query == "SELECT revision,payload FROM v38_workbench_snapshot WHERE id=1"}, nil
}
func (c *clearConnection) ExecContext(_ context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	if query != "DELETE FROM v38_workbench_snapshot WHERE id=1 AND revision=?" || len(args) != 1 || args[0].Value != c.fixture.revision {
		return nil, errors.New("must not delete other rows, tables or revisions")
	}
	if c.fixture.execFail {
		return nil, errors.New("delete failed")
	}
	c.fixture.deleted = true
	return driver.RowsAffected(c.fixture.affected), nil
}
func (tx *clearTransaction) Commit() error {
	if tx.fixture.commitFail {
		return errors.New("commit failed")
	}
	tx.fixture.committed = true
	return nil
}
func (tx *clearTransaction) Rollback() error { tx.fixture.rolledBack = true; return nil }
func (*clearRows) Columns() []string         { return []string{"revision", "payload"} }
func (*clearRows) Close() error              { return nil }
func (r *clearRows) Next(values []driver.Value) error {
	if r.read || r.fixture.empty {
		return io.EOF
	}
	r.read = true
	values[0] = r.fixture.revision
	values[1] = r.fixture.encrypted
	if r.unlocked && r.fixture.changeAfterLoad {
		r.fixture.revision++
	}
	return nil
}

type clearBackupFixture struct{ raw []byte }

func (b clearBackupFixture) Load() ([]byte, error) { return b.raw, nil }
func (b clearBackupFixture) Save([]byte) error     { return errors.New("read-only backup fixture") }

func TestClearFromBackupRefusesUnbackedChangesAndCorruptEvidence(t *testing.T) {
	for _, name := range []string{"same-data", "new-data-after-backup", "write-after-comparison", "already-empty", "bad-manifest", "bad-key", "missing-manifest", "bad-bytes", "bad-format"} {
		t.Run(name, func(t *testing.T) {
			key := make([]byte, 32)
			keyFile := filepath.Join(t.TempDir(), "storage.key")
			if err := os.WriteFile(keyFile, key, 0600); err != nil {
				t.Fatal(err)
			}
			backup := filepath.Join(t.TempDir(), "reference.wbbak")
			raw := []byte(`{"orders":[],"version":"A"}`)
			if _, err := WriteBackup(clearBackupFixture{raw}, keyFile, backup); err != nil {
				t.Fatal(err)
			}
			fixture := &clearFixture{key: key, revision: 7, affected: 1}
			fixture.encrypted, _ = seal(key, raw)
			db := sql.OpenDB(clearConnector{fixture})
			defer db.Close()
			p := &TiDBPersistence{db: db, key: key}
			switch name {
			case "new-data-after-backup":
				fixture.encrypted, _ = seal(key, []byte(`{"orders":[],"version":"B"}`))
			case "write-after-comparison":
				fixture.changeAfterLoad = true
			case "already-empty":
				fixture.empty = true
			case "bad-manifest":
				if err := os.WriteFile(backup+".manifest.json", []byte(`{}`), 0600); err != nil {
					t.Fatal(err)
				}
			case "bad-key":
				p.key = make([]byte, 32)
				p.key[0] = 1
			case "missing-manifest":
				if err := os.Remove(backup + ".manifest.json"); err != nil {
					t.Fatal(err)
				}
			case "bad-bytes", "bad-format":
				body, err := os.ReadFile(backup + ".manifest.json")
				if err != nil {
					t.Fatal(err)
				}
				var manifest BackupManifest
				if err = json.Unmarshal(body, &manifest); err != nil {
					t.Fatal(err)
				}
				if name == "bad-bytes" {
					manifest.Bytes++
				} else {
					manifest.Format = "other-format"
				}
				body, _ = json.Marshal(manifest)
				if err = os.WriteFile(backup+".manifest.json", body, 0600); err != nil {
					t.Fatal(err)
				}
			}
			err := p.ClearApplicationSnapshotFromBackup(backup)
			wantSuccess := name == "same-data" || name == "already-empty"
			if (err == nil) != wantSuccess || fixture.committed != wantSuccess {
				t.Fatalf("clear %s: %v committed=%v", name, err, fixture.committed)
			}
			if !wantSuccess && fixture.deleted {
				t.Fatal("unbacked or unverified database row was deleted")
			}
		})
	}
}

func TestClearApplicationSnapshotScopeAndFailureBoundaries(t *testing.T) {
	for _, name := range []string{"success", "already-empty", "wrong-key", "stale-instance", "revision-conflict", "query-failure", "delete-failure", "commit-failure"} {
		t.Run(name, func(t *testing.T) {
			fixture := &clearFixture{key: make([]byte, 32), revision: 7, affected: 1}
			var err error
			fixture.encrypted, err = seal(fixture.key, []byte(`{"orders":[],"accounts":[]}`))
			if err != nil {
				t.Fatal(err)
			}
			db := sql.OpenDB(clearConnector{fixture})
			defer db.Close()
			p := &TiDBPersistence{db: db, key: fixture.key}
			switch name {
			case "already-empty":
				fixture.empty = true
			case "wrong-key":
				p.key = make([]byte, 32)
				p.key[0] = 1
			case "stale-instance":
				p.loaded = true
				p.revision = 6
			case "revision-conflict":
				fixture.affected = 0
			case "query-failure":
				fixture.queryFail = true
			case "delete-failure":
				fixture.execFail = true
			case "commit-failure":
				fixture.commitFail = true
			}
			err = p.ClearApplicationSnapshot()
			wantSuccess := name == "success" || name == "already-empty"
			if (err == nil) != wantSuccess {
				t.Fatalf("success=%v err=%v", wantSuccess, err)
			}
			if fixture.committed != wantSuccess {
				t.Fatal("failed clear committed")
			}
			if (name == "wrong-key" || name == "stale-instance" || name == "query-failure" || name == "already-empty") && fixture.deleted {
				t.Fatal("unverified or empty snapshot deleted")
			}
			if name == "success" && (!p.loaded || p.revision != 7) {
				t.Fatal("clear allowed old persistence instance to insert data again")
			}
		})
	}
}
