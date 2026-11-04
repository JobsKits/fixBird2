package workbench

import (
	"bytes"
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/go-sql-driver/mysql"
)

func TestTiDBPersistenceEncryptedCASAndRestart(t *testing.T) {
	dsn := os.Getenv("WB_TEST_TIDB_DSN")
	if dsn == "" {
		t.Skip("WB_TEST_TIDB_DSN 未设置，跳过独立TiDB集成")
	}
	config, err := mysql.ParseDSN(dsn)
	if err != nil {
		t.Fatal(err)
	}
	config.DBName = ""
	connector, err := mysql.NewConnector(config)
	if err != nil {
		t.Fatal(err)
	}
	db := sql.OpenDB(connector)
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	const database = "v38_storage_validation_only"
	if _, err = db.ExecContext(ctx, "CREATE DATABASE "+database); err != nil {
		t.Fatal("测试数据库已存在或无法创建，拒绝碰已有数据: ", err)
	}
	defer db.ExecContext(context.Background(), "DROP DATABASE "+database)
	config.DBName = database
	key := filepath.Join(t.TempDir(), "keys", "key")
	a, err := NewTiDBPersistence(config.FormatDSN(), key, false)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	if raw, err := a.Load(); err != nil || len(raw) != 0 {
		t.Fatalf("initial load %s %v", raw, err)
	}
	first := []byte(`{"accounts":[],"orders":[],"private":"not-readable-in-database"}`)
	if err = a.Save(first); err != nil {
		t.Fatal(err)
	}
	b, err := NewTiDBPersistence(config.FormatDSN(), key, false)
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	if got, err := b.Load(); err != nil || !bytes.Equal(got, first) {
		t.Fatalf("restart %s %v", got, err)
	}
	second := []byte(`{"accounts":[],"orders":[],"version":2}`)
	if err = a.Save(second); err != nil {
		t.Fatal(err)
	}
	if err = b.Save([]byte(`{"version":3}`)); err == nil {
		t.Fatal("stale database writer accepted")
	}
	if _, err = b.Load(); err == nil {
		t.Fatal("backup read silently advanced stale writer revision")
	}
	c, err := NewTiDBPersistence(config.FormatDSN(), key, false)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	got, err := c.Load()
	if err != nil || !bytes.Equal(got, second) {
		t.Fatalf("CAS data %s %v", got, err)
	}
	var encrypted []byte
	if err = a.db.QueryRowContext(ctx, "SELECT payload FROM v38_workbench_snapshot WHERE id=1").Scan(&encrypted); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encrypted, []byte("accounts")) || bytes.Contains(encrypted, []byte("version")) {
		t.Fatal("plaintext payload in database")
	}
}

func TestTiDBTLSRejectsUnsafeConfigurationBeforeNetwork(t *testing.T) {
	for _, dsn := range []string{"root@tcp(192.0.2.1:4000)/test?tls=false", "root@tcp(192.0.2.1:4000)/test?tls=skip-verify", "root@tcp(127.0.0.1:14038)/test?tls=false"} {
		if _, err := NewTiDBPersistence(dsn, filepath.Join(t.TempDir(), "key"), true); err == nil {
			t.Fatal("unsafe TLS accepted")
		}
	}
}
