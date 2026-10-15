package repository_test

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"testing/fstest"
	"time"

	"github.com/go-sql-driver/mysql"
	"repair-platform/internal/domain"
	"repair-platform/internal/migration"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
)

// Integration uses a fresh disposable schema on an explicitly supplied loopback test server.
func testTiDB(t *testing.T, modes ...string) repository.Repository {
	t.Helper()
	dsn := os.Getenv("REPAIR_TEST_TIDB_DSN")
	if dsn == "" {
		t.Skip("set REPAIR_TEST_TIDB_DSN to an isolated loopback TiDB with a repair_test_ schema")
	}
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		t.Fatal(err)
	}
	mode := "pessimistic"
	if len(modes) > 0 {
		mode = modes[0]
	}
	if cfg.Params == nil {
		cfg.Params = make(map[string]string)
	}
	cfg.Params["tidb_txn_mode"] = "'" + mode + "'"
	host, _, err := net.SplitHostPort(cfg.Addr)
	if err != nil || cfg.Net != "tcp" || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() || !regexp.MustCompile(`^repair_test_[a-zA-Z0-9_]+$`).MatchString(cfg.DBName) {
		t.Fatal("integration DSN must name a repair_test_ database on a loopback TCP address")
	}
	name := fmt.Sprintf("repair_test_contract_%d", time.Now().UnixNano())
	cfg.DBName = ""
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	bootstrap, err := repository.OpenTiDB(ctx, cfg.FormatDSN())
	if err != nil {
		t.Fatal(err)
	}
	if err := bootstrap.Exec(ctx, "CREATE DATABASE `"+name+"`"); err != nil {
		_ = bootstrap.Close()
		t.Fatal(err)
	}
	cfg.DBName = name
	store, err := repository.OpenTiDB(ctx, cfg.FormatDSN())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = store.Close()
		cleanup, done := context.WithTimeout(context.Background(), 10*time.Second)
		defer done()
		if err := bootstrap.Exec(cleanup, "DROP DATABASE `"+name+"`"); err != nil {
			t.Errorf("cleanup test database: %v", err)
		}
		_ = bootstrap.Close()
	})
	if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), ""); err != nil {
		t.Fatal(err)
	}
	if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), ""); err != nil {
		t.Fatal("repeat migrations", err)
	}
	if err := migration.Seed(ctx, store.DB(), os.DirFS("../../seeds"), "demo.sql"); err != nil {
		t.Fatal(err)
	}
	if err := store.Ready(ctx); err != nil {
		t.Fatal(err)
	}
	return store
}

func TestTiDBMigrationUpgradeChecksumAndSeed(t *testing.T) {
	store := testTiDB(t).(*repository.TiDB)
	ctx := context.Background()
	// Simulate the previous unversioned schema inside the disposable test database.
	for _, statement := range []string{
		"DROP TABLE repair_schema_migrations", "DROP TABLE repair_order_requests",
		"ALTER TABLE repair_orders DROP COLUMN profit_rule_version",
		"ALTER TABLE repair_settlements DROP COLUMN profit_rule_version",
		"UPDATE repair_workers SET display_name = '保留自定义名字' WHERE id = 'worker-demo'",
	} {
		if err := store.Exec(ctx, statement); err != nil {
			t.Fatal(err)
		}
	}
	if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), ""); err != nil {
		t.Fatal("legacy adoption", err)
	}
	if err := migration.Seed(ctx, store.DB(), os.DirFS("../../seeds"), "demo.sql"); err != nil {
		t.Fatal(err)
	}
	var name string
	if err := store.DB().QueryRowContext(ctx, "SELECT display_name FROM repair_workers WHERE id = 'worker-demo'").Scan(&name); err != nil || name != "保留自定义名字" {
		t.Fatal("seed overwrote existing data", name, err)
	}
	files := fstest.MapFS{}
	entries, err := os.ReadDir("../../migrations")
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		payload, err := os.ReadFile("../../migrations/" + entry.Name())
		if err != nil {
			t.Fatal(err)
		}
		files[entry.Name()] = &fstest.MapFile{Data: payload}
	}
	original := files["001_init.sql"].Data
	files["001_init.sql"] = &fstest.MapFile{Data: append(append([]byte(nil), original...), []byte("\n-- changed\n")...)}
	if err := migration.Run(ctx, store.DB(), files, ""); err == nil || !strings.Contains(err.Error(), "checksum mismatch") {
		t.Fatal("changed migration accepted", err)
	}
	if err := store.Exec(ctx, "UPDATE repair_schema_migrations SET dirty = TRUE WHERE version = '003_profit_rule.sql'"); err != nil {
		t.Fatal(err)
	}
	if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), ""); err == nil || !strings.Contains(err.Error(), "dirty") {
		t.Fatal("implicit dirty resume", err)
	}
	if err := store.Ready(ctx); err == nil {
		t.Fatal("dirty schema reports ready")
	}
	if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), "003_profit_rule.sql"); err != nil {
		t.Fatal("explicit dirty resume", err)
	}
	if err := store.Ready(ctx); err != nil {
		t.Fatal(err)
	}
	var group sync.WaitGroup
	for i := 0; i < 4; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			if err := migration.Run(ctx, store.DB(), os.DirFS("../../migrations"), ""); err != nil {
				t.Errorf("concurrent migration: %v", err)
			}
		}()
	}
	group.Wait()
}

func TestRepositoryContract(t *testing.T) {
	for _, backend := range []string{"memory", "tidb-pessimistic", "tidb-optimistic"} {
		t.Run(backend, func(t *testing.T) {
			var repo repository.Repository = repository.NewMemory()
			if backend != "memory" {
				repo = testTiDB(t, strings.TrimPrefix(backend, "tidb-"))
			}
			ctx := context.Background()
			now := time.Now().UTC().Truncate(time.Millisecond)
			makeOrder := func(id, actor string) domain.Order {
				return domain.Order{ID: id, CustomerID: actor, Category: "家电维修", Equipment: "冰箱", Issue: "不制冷", Address: "测试地址", Status: domain.StatusPendingWorker, PaymentStatus: domain.PaymentNotStarted, CreatedAt: now, UpdatedAt: now}
			}
			a := makeOrder("ord_a", "customer-a")
			first, replay, err := repo.CreateOrder(ctx, a, "same-key", strings.Repeat("a", 64))
			if err != nil || replay || first.ID != a.ID {
				t.Fatal(first, replay, err)
			}
			copy := makeOrder("ord_duplicate_candidate", "customer-a")
			second, replay, err := repo.CreateOrder(ctx, copy, "same-key", strings.Repeat("a", 64))
			if err != nil || !replay || second.ID != a.ID {
				t.Fatal("lost idempotency", second, replay, err)
			}
			if _, _, err := repo.CreateOrder(ctx, copy, "same-key", strings.Repeat("b", 64)); !errors.Is(err, repository.ErrIdempotencyConflict) {
				t.Fatal("different request must conflict", err)
			}
			other := makeOrder("ord_other", "customer-other")
			if _, _, err := repo.CreateOrder(ctx, other, "same-key", strings.Repeat("a", 64)); err != nil {
				t.Fatal("key leaked across customer scope", err)
			}
			for _, id := range []string{"ord_b", "ord_c"} {
				if _, _, err := repo.CreateOrder(ctx, makeOrder(id, "customer-a"), "", ""); err != nil {
					t.Fatal(err)
				}
			}
			query := domain.ListQuery{Actor: domain.Actor{ID: "customer-a", Role: domain.RoleCustomer}, Limit: 1}
			page, err := repo.ListOrders(ctx, query)
			if err != nil || len(page) != 2 || page[0].ID != "ord_c" {
				t.Fatal("filtered stable page", page, err)
			}
			query.Before = &domain.Cursor{CreatedAt: page[0].CreatedAt, ID: page[0].ID}
			page, err = repo.ListOrders(ctx, query)
			if err != nil || len(page) != 2 || page[0].ID != "ord_b" {
				t.Fatal("cursor page", page, err)
			}
			var group sync.WaitGroup
			ids := make(chan string, 16)
			for i := 0; i < 16; i++ {
				group.Add(1)
				go func(i int) {
					defer group.Done()
					for attempt := 0; attempt < 4; attempt++ {
						order, _, err := repo.CreateOrder(ctx, makeOrder(fmt.Sprintf("ord_retry_%d", i), "customer-concurrent"), "concurrent-key", strings.Repeat("c", 64))
						if errors.Is(err, repository.ErrRetryable) {
							time.Sleep(30 * time.Millisecond)
							continue
						}
						if err != nil {
							t.Errorf("concurrent create: %v", err)
							return
						}
						ids <- order.ID
						return
					}
					t.Error("concurrent create remained retryable")
				}(i)
			}
			group.Wait()
			close(ids)
			winner, count := "", 0
			for id := range ids {
				if winner == "" {
					winner = id
				}
				if id != winner {
					t.Error("duplicate created order", id, winner)
				}
				count++
			}
			if count != 16 {
				t.Fatal("idempotent requests did not resolve", count)
			}
			var accepted atomic.Int64
			for i := 0; i < 16; i++ {
				group.Add(1)
				go func(i int) {
					defer group.Done()
					order := a
					order.Status = domain.StatusAccepted
					order.WorkerID = fmt.Sprintf("worker-%d", i)
					err := repo.SaveOrder(ctx, order, domain.StatusPendingWorker)
					if err == nil {
						accepted.Add(1)
					} else if !errors.Is(err, repository.ErrInvalidState) {
						t.Errorf("accept: %v", err)
					}
				}(i)
			}
			group.Wait()
			if accepted.Load() != 1 {
				t.Fatal("multiple accepted workers", accepted.Load())
			}
			payable := makeOrder("ord_payable", "customer-a")
			payable.WorkerID, payable.Status, payable.QuotedAmountCents = "worker-demo", domain.StatusAwaitingPay, 10
			if _, _, err := repo.CreateOrder(ctx, payable, "", ""); err != nil {
				t.Fatal(err)
			}
			paid := payable
			paid.Status, paid.PaymentStatus, paid.WorkerShareCents, paid.PlatformFeeCents, paid.ProfitRuleVersion = domain.StatusCompleted, domain.PaymentDemoPaid, 9, 1, domain.ProfitRuleVersion
			var collected atomic.Int64
			for i := 0; i < 16; i++ {
				group.Add(1)
				go func(i int) {
					defer group.Done()
					settlement := domain.Settlement{ID: fmt.Sprintf("set_%d", i), OrderID: payable.ID, WorkerID: "worker-demo", GrossAmountCents: 10, WorkerShareCents: 9, PlatformFeeCents: 1, ProfitRuleVersion: domain.ProfitRuleVersion, Status: domain.SettlementPendingManual, CreatedAt: now}
					err := repo.DemoCollect(ctx, paid, settlement)
					if err == nil {
						collected.Add(1)
					} else if !errors.Is(err, repository.ErrInvalidState) {
						t.Errorf("collect: %v", err)
					}
				}(i)
			}
			group.Wait()
			if collected.Load() != 1 {
				t.Fatal("duplicate collections", collected.Load())
			}
			settlements, err := repo.ListSettlements(ctx, domain.ListQuery{Limit: 100})
			if err != nil || len(settlements) != 1 || settlements[0].ProfitRuleVersion != domain.ProfitRuleVersion {
				t.Fatal(settlements, err)
			}
			for i := 0; i < 2; i++ {
				if err := repo.MarkSettlementManuallyPaid(ctx, settlements[0].ID); err != nil {
					t.Fatal("manual paid not idempotent", err)
				}
			}
			if err := repo.MarkSettlementManuallyPaid(ctx, "missing-settlement"); !errors.Is(err, repository.ErrNotFound) {
				t.Fatal("missing settlement", err)
			}
			dashboard, err := repo.Dashboard(ctx)
			if err != nil || dashboard.GrossAmountCents != 10 || dashboard.WorkerShareCents != 9 || dashboard.PlatformFeeCents != 1 || dashboard.PendingSettlements != 0 {
				t.Fatal(dashboard, err)
			}
			marketplace := service.NewMarketplace(repo, true)
			admin := domain.Actor{ID: "admin-demo", Role: domain.RoleAdmin}
			if replay, err := marketplace.DemoCollect(ctx, admin, payable.ID); err != nil || replay.ID != payable.ID || replay.WorkerShareCents != 9 {
				t.Fatal("completed service replay", replay, err)
			}
			settlements, err = repo.ListSettlements(ctx, domain.ListQuery{Limit: 100})
			if err != nil || len(settlements) != 1 || settlements[0].Status != domain.SettlementManuallyPaid {
				t.Fatal("collection replay reset settlement", settlements, err)
			}
			concurrentPayable := payable
			concurrentPayable.ID = "ord_service_collect"
			if _, _, err := repo.CreateOrder(ctx, concurrentPayable, "", ""); err != nil {
				t.Fatal(err)
			}
			for i := 0; i < 16; i++ {
				group.Add(1)
				go func() {
					defer group.Done()
					order, err := marketplace.DemoCollect(ctx, admin, concurrentPayable.ID)
					if err != nil || order.ID != concurrentPayable.ID || order.PaymentStatus != domain.PaymentDemoPaid {
						t.Errorf("concurrent service collect: order=%+v err=%v", order, err)
					}
				}()
			}
			group.Wait()
			settlements, err = repo.ListSettlements(ctx, domain.ListQuery{Limit: 100})
			if err != nil || len(settlements) != 2 {
				t.Fatal("concurrent service duplicated settlement", settlements, err)
			}
			cancelled, cancel := context.WithCancel(ctx)
			cancel()
			if _, err := repo.ListOrders(cancelled, query); !errors.Is(err, context.Canceled) {
				t.Fatal("ignored cancellation", err)
			}
		})
	}
}
