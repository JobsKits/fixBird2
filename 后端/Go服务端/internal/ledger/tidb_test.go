package ledger_test

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net"
	"os"
	"regexp"
	"sync"
	"testing"
	"time"

	"github.com/go-sql-driver/mysql"
	"repair-platform/internal/ledger"
	"repair-platform/internal/migration"
)

// Require an explicit disposable loopback test service; never reuse the supplied database itself.
func testDatabase(t *testing.T) (*ledger.TiDB, *sql.DB) {
	t.Helper()
	dsn := os.Getenv("REPAIR_TEST_TIDB_DSN")
	if dsn == "" {
		t.Skip("ledger TiDB contract requires an isolated REPAIR_TEST_TIDB_DSN")
	}
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		t.Fatal(err)
	}
	host, _, err := net.SplitHostPort(cfg.Addr)
	if err != nil || cfg.Net != "tcp" || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() || !regexp.MustCompile(`^repair_test_[a-zA-Z0-9_]+$`).MatchString(cfg.DBName) {
		t.Fatal("ledger integration DSN must be loopback TCP with repair_test_ database")
	}
	cfg.ParseTime, cfg.Loc = true, time.UTC
	cfg.Timeout, cfg.ReadTimeout, cfg.WriteTimeout = 5*time.Second, 5*time.Second, 5*time.Second
	if cfg.Params == nil {
		cfg.Params = make(map[string]string)
	}
	cfg.Params["tidb_txn_mode"] = "'pessimistic'"
	cfg.DBName = ""
	bootstrap, err := sql.Open("mysql", cfg.FormatDSN())
	if err != nil {
		t.Fatal(err)
	}
	name := fmt.Sprintf("repair_test_ledger_%d", time.Now().UnixNano())
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if _, err := bootstrap.ExecContext(ctx, "CREATE DATABASE `"+name+"`"); err != nil {
		_ = bootstrap.Close()
		t.Fatal(err)
	}
	cfg.DBName = name
	db, err := sql.Open("mysql", cfg.FormatDSN())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = db.Close()
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if _, err := bootstrap.ExecContext(cleanup, "DROP DATABASE `"+name+"`"); err != nil {
			t.Errorf("ledger disposable database cleanup: %v", err)
		}
		_ = bootstrap.Close()
	})
	if err := migration.Run(ctx, db, os.DirFS("../../migrations"), ""); err != nil {
		t.Fatal(err)
	}
	store := ledger.NewTiDB(db)
	if err := store.Ready(ctx); err != nil {
		t.Fatal(err)
	}
	return store, db
}

func TestTiDBStoreContract(t *testing.T) {
	store, _ := testDatabase(t)
	storeContract(t, store)
}

func TestTiDBConcurrentEventAndBusinessTransactionRollback(t *testing.T) {
	store, db := testDatabase(t)
	ctx := context.Background()
	journal := collection(t, "db-concurrent", 10, 9)
	var group sync.WaitGroup
	for index := 0; index < 16; index++ {
		group.Add(1)
		go func() {
			defer group.Done()
			if _, err := store.Append(ctx, journal); err != nil {
				t.Error(err)
			}
		}()
	}
	group.Wait()
	summary, err := store.Summary(ctx, ledger.Query{})
	if err != nil || summary.JournalCount != 1 {
		t.Fatal(summary, err)
	}
	if _, err := db.ExecContext(ctx, "CREATE TABLE ledger_test_business (id VARCHAR(64) PRIMARY KEY)"); err != nil {
		t.Fatal(err)
	}
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO ledger_test_business (id) VALUES ('order-db-rollback')"); err != nil {
		t.Fatal(err)
	}
	rolledBack := collection(t, "db-rollback", 100, 85)
	if _, err := store.AppendTx(ctx, tx, rolledBack); err != nil {
		t.Fatal(err)
	}
	if err := tx.Rollback(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Get(ctx, rolledBack.ID); !errors.Is(err, ledger.ErrNotFound) {
		t.Fatal("rolled-back journal visible", err)
	}
	var businessRows, entries int
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM ledger_test_business").Scan(&businessRows); err != nil {
		t.Fatal(err)
	}
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM repair_ledger_entries WHERE journal_id=?", rolledBack.ID).Scan(&entries); err != nil {
		t.Fatal(err)
	}
	if businessRows != 0 || entries != 0 {
		t.Fatal("business/journal rollback diverged", businessRows, entries)
	}
}

func TestTiDBAdoptsLegacyLedgerIdempotentlyAndPreservesProvenance(t *testing.T) {
	store, db := testDatabase(t)
	ctx := context.Background()
	at := time.Date(2026, 1, 2, 12, 0, 0, 0, time.UTC)
	if _, err := db.ExecContext(ctx, `INSERT INTO repair_orders
 (id,customer_id,worker_id,category,equipment,issue,address,status,payment_status,quoted_amount_cents,worker_share_cents,platform_fee_cents,created_at)
 VALUES ('legacy-order','legacy-customer','legacy-worker','维修','冰箱','测试','测试地址','completed','demo_paid',100,85,15,?)`, at); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `INSERT INTO repair_settlements
 (id,order_id,worker_id,gross_amount_cents,worker_share_cents,platform_fee_cents,status,created_at,updated_at)
 VALUES ('legacy-settlement','legacy-order','legacy-worker',100,85,15,'manually_paid',?,?)`, at, at.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `INSERT INTO repair_payments (id,order_id,provider,amount_cents,status,created_at)
 VALUES ('legacy-payment','legacy-order','manual_demo',100,'demo_paid',?)`, at); err != nil {
		t.Fatal(err)
	}
	for index := 0; index < 2; index++ {
		if err := store.Backfill(ctx); err != nil {
			t.Fatal("legacy backfill", err)
		}
	}
	summary, err := store.Summary(ctx, ledger.Query{})
	if err != nil || summary.JournalCount != 2 || summary.CollectedCents != 100 || summary.PayoutCents != 85 || summary.PlatformFundsCents != 15 || summary.WorkerPayableCents != 0 {
		t.Fatal(summary, err)
	}
	adopted, err := store.GetEvent(ctx, ledger.CollectionEventKey(ledger.ModeSimulated, "legacy-order"))
	if err != nil || !adopted.Simulated || adopted.Channel != ledger.ChannelDemo || !adopted.OccurredAt.Equal(at) {
		t.Fatal(adopted, err)
	}
	var businessStatus string
	if err := db.QueryRowContext(ctx, "SELECT status FROM repair_settlements WHERE id='legacy-settlement'").Scan(&businessStatus); err != nil || businessStatus != "manually_paid" {
		t.Fatal("backfill changed business record", businessStatus, err)
	}
	if _, err := db.ExecContext(ctx, `INSERT INTO repair_payments (id,order_id,provider,amount_cents,status)
 VALUES ('orphan-payment','missing-order','manual_demo',10,'demo_paid')`); err != nil {
		t.Fatal(err)
	}
	if err := store.Backfill(ctx); !errors.Is(err, ledger.ErrInvalidState) {
		t.Fatal("orphan receipt silently discarded", err)
	}
	summary, err = store.Summary(ctx, ledger.Query{})
	if err != nil || summary.JournalCount != 2 {
		t.Fatal("failed backfill mutated ledger", summary, err)
	}
}
