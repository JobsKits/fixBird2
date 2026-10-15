package ledger_test

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/csv"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"repair-platform/internal/ledger"
)

func collection(t *testing.T, suffix string, amount, share int64) ledger.Journal {
	t.Helper()
	journal, err := ledger.NewCollection(ledger.Collection{OrderID: "order-" + suffix, CustomerID: "customer-" + suffix, WorkerID: "worker-" + suffix,
		SettlementID: "settlement-" + suffix, AmountCents: amount, WorkerShareCents: share, PlatformFeeCents: amount - share, ActorID: "admin-test",
		OccurredAt: time.Date(2026, 10, 5, 12, 0, 0, 0, time.UTC)})
	if err != nil {
		t.Fatal(err)
	}
	return journal
}

func payout(t *testing.T, original ledger.Journal, amount int64) ledger.Journal {
	t.Helper()
	journal, err := ledger.NewPayout(ledger.Payout{OrderID: original.OrderID, CustomerID: original.CustomerID, WorkerID: original.WorkerID,
		SettlementID: original.SettlementID, AmountCents: amount, ActorID: "admin-test", OccurredAt: original.OccurredAt.Add(time.Hour)})
	if err != nil {
		t.Fatal(err)
	}
	return journal
}

func mustAppend(t *testing.T, store ledger.Store, journal ledger.Journal) ledger.Journal {
	t.Helper()
	saved, err := store.Append(context.Background(), journal)
	if err != nil {
		t.Fatal(err)
	}
	return saved
}

func assertBalanced(t *testing.T, journal ledger.Journal) {
	t.Helper()
	var debit, credit int64
	for _, entry := range journal.Entries {
		if entry.Direction == ledger.Debit {
			debit += entry.AmountCents
		} else {
			credit += entry.AmountCents
		}
	}
	if debit != credit {
		t.Fatalf("unbalanced debit=%d credit=%d: %+v", debit, credit, journal)
	}
}

func TestMoneyConservationAndRealChannelsDoNotCreateJournals(t *testing.T) {
	for _, amount := range []int64{1, 5, 10, 11, 99, 101, ledger.MaxAmountCents} {
		share := (amount*85 + 50) / 100
		journal := collection(t, "money", amount, share)
		assertBalanced(t, journal)
		if journal.WorkerShareCents+journal.PlatformFeeCents != amount || !journal.Simulated || journal.Mode != ledger.ModeSimulated {
			t.Fatal(journal)
		}
	}
	for _, invalid := range []int64{0, -1, ledger.MaxAmountCents + 1} {
		_, err := ledger.NewCollection(ledger.Collection{OrderID: "order", CustomerID: "customer", WorkerID: "worker", SettlementID: "settlement", AmountCents: invalid, WorkerShareCents: 1})
		if err == nil {
			t.Fatal("invalid amount accepted", invalid)
		}
	}
	for _, channel := range []string{"wechat", "alipay", "aggregate"} {
		_, err := ledger.NewCollection(ledger.Collection{OrderID: "order", CustomerID: "customer", WorkerID: "worker", SettlementID: "settlement", Channel: channel, AmountCents: 10, WorkerShareCents: 9, PlatformFeeCents: 1})
		if !errors.Is(err, ledger.ErrRealNotConfigured) {
			t.Fatal(channel, err)
		}
	}
	_, err := ledger.NewCollection(ledger.Collection{Mode: ledger.ModeActual, OrderID: "order", CustomerID: "customer", WorkerID: "worker", SettlementID: "settlement", AmountCents: 10, WorkerShareCents: 9, PlatformFeeCents: 1})
	if !errors.Is(err, ledger.ErrRealNotConfigured) {
		t.Fatal(err)
	}
}

func TestMemoryConcurrentIdempotencyAndImmutableCopies(t *testing.T) {
	store := ledger.NewMemory()
	journal := collection(t, "race", 10, 9)
	var group sync.WaitGroup
	for index := 0; index < 24; index++ {
		group.Add(1)
		go func() {
			defer group.Done()
			if _, err := store.Append(context.Background(), journal); err != nil {
				t.Error(err)
			}
		}()
	}
	group.Wait()
	page, err := ledger.NewService(store).List(context.Background(), ledger.Query{})
	if err != nil || len(page.Items) != 1 {
		t.Fatal(page, err)
	}
	page.Items[0].Entries[0].AmountCents = 999
	original, err := store.Get(context.Background(), journal.ID)
	if err != nil || original.Entries[0].AmountCents != 10 {
		t.Fatal(original, err)
	}
	changed := collection(t, "race", 11, 9)
	if _, err := store.Append(context.Background(), changed); !errors.Is(err, ledger.ErrIdempotencyConflict) {
		t.Fatal("changed money must conflict", err)
	}
	journal.Entries[0].AmountCents++
	if _, err := store.Append(context.Background(), journal); !errors.Is(err, ledger.ErrInvalidInput) {
		t.Fatal("malformed balance accepted", err)
	}
}

func TestMemoryBusinessCallbackIsAtomicAndNotReplayed(t *testing.T) {
	store := ledger.NewMemory()
	journal := collection(t, "atomic", 100, 85)
	businessWrites := 0
	if _, err := store.AppendWith(context.Background(), journal, func() error { return errors.New("business commit failed") }); err == nil {
		t.Fatal("callback error lost")
	}
	if _, err := store.Get(context.Background(), journal.ID); !errors.Is(err, ledger.ErrNotFound) {
		t.Fatal("failed business wrote journal", err)
	}
	commit := func() error { businessWrites++; return nil }
	if _, err := store.AppendWith(context.Background(), journal, commit); err != nil {
		t.Fatal(err)
	}
	if _, err := store.AppendWith(context.Background(), journal, commit); err != nil || businessWrites != 1 {
		t.Fatal("callback replayed", businessWrites, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := store.AppendWith(ctx, collection(t, "cancel", 100, 85), commit); !errors.Is(err, context.Canceled) || businessWrites != 1 {
		t.Fatal(err, businessWrites)
	}
}

// Run this same semantic contract against Memory and a disposable TiDB database.
func storeContract(t *testing.T, store ledger.Store) {
	t.Helper()
	ctx := context.Background()
	collected := collection(t, "contract", 10, 9)
	paid := payout(t, collected, 9)
	if _, err := store.Append(ctx, paid); !errors.Is(err, ledger.ErrInvalidState) {
		t.Fatal("payout before collection", err)
	}
	collected = mustAppend(t, store, collected)
	wrong := payout(t, collected, 8)
	if _, err := store.Append(ctx, wrong); !errors.Is(err, ledger.ErrInvalidState) {
		t.Fatal("over/under payout accepted", err)
	}
	paid = mustAppend(t, store, paid)
	mustAppend(t, store, paid)
	summary, err := store.Summary(ctx, ledger.Query{})
	if err != nil || summary.JournalCount != 2 || summary.CollectedCents != 10 || summary.PayoutCents != 9 || summary.PlatformFundsCents != 1 || summary.WorkerPayableCents != 0 {
		t.Fatal(summary, err)
	}
	if summary.Scope != "filtered_movements" || !summary.Simulated {
		t.Fatal(summary)
	}
	reverseCollection, err := ledger.NewReversal(collected, "reverse-collection", "admin-test", "correct simulated record", paid.OccurredAt.Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Append(ctx, reverseCollection); !errors.Is(err, ledger.ErrInvalidState) {
		t.Fatal("collection reversed while payout active", err)
	}
	reversePayout, err := ledger.NewReversal(paid, "reverse-payout", "admin-test", "correct simulated attestation", paid.OccurredAt.Add(time.Minute))
	if err != nil {
		t.Fatal(err)
	}
	mustAppend(t, store, reversePayout)
	mustAppend(t, store, reversePayout)
	mustAppend(t, store, reverseCollection)
	summary, err = store.Summary(ctx, ledger.Query{})
	if err != nil || summary.JournalCount != 4 || summary.CollectedCents != 0 || summary.PayoutCents != 0 || summary.PlatformFundsCents != 0 || summary.WorkerPayableCents != 0 || summary.PlatformRevenueCents != 0 {
		t.Fatal(summary, err)
	}
	original, err := store.Get(ctx, collected.ID)
	if err != nil || original.Status != ledger.StatusReversed || original.Entries[0].Direction != ledger.Debit {
		t.Fatal("original journal overwritten", original, err)
	}
	otherReversal, err := ledger.NewReversal(collected, "reverse-again", "admin-test", "duplicate correction", paid.OccurredAt.Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Append(ctx, otherReversal); !errors.Is(err, ledger.ErrInvalidState) {
		t.Fatal("double reversal accepted", err)
	}
	items, err := store.List(ctx, ledger.Query{Status: ledger.StatusReversed})
	if err != nil || len(items) != 2 {
		t.Fatal(items, err)
	}
	actual, err := store.Summary(ctx, ledger.Query{Mode: ledger.ModeActual})
	if err != nil || actual.JournalCount != 0 || actual.Simulated {
		t.Fatal("simulated/actual leakage", actual, err)
	}
}

func TestMemoryStoreContract(t *testing.T) { storeContract(t, ledger.NewMemory()) }

func TestFilteredPagingDateBoundariesAndExport(t *testing.T) {
	store := ledger.NewMemory()
	first := collection(t, "first", 100, 85)
	first.Reason = "=SUM(1,2)\n人工备注"
	// Audit notes do not change financial fingerprint and are still immutable after append.
	mustAppend(t, store, first)
	second := collection(t, "second", 10, 9)
	mustAppend(t, store, second)
	service := ledger.NewService(store)
	page, err := service.List(context.Background(), ledger.Query{Limit: 1})
	if err != nil || len(page.Items) != 1 || page.NextCursor == "" {
		t.Fatal(page, err)
	}
	cursor, err := ledger.DecodeCursor(page.NextCursor)
	if err != nil {
		t.Fatal(err)
	}
	next, err := service.List(context.Background(), ledger.Query{Limit: 1, Before: cursor})
	if err != nil || len(next.Items) != 1 || next.Items[0].ID == page.Items[0].ID || next.NextCursor != "" {
		t.Fatal(next, err)
	}
	filtered, err := service.List(context.Background(), ledger.Query{WorkerID: first.WorkerID, CustomerID: first.CustomerID, OrderID: first.OrderID, Channel: ledger.ChannelDemo, Kind: ledger.KindCollection, From: first.OccurredAt, To: first.OccurredAt.Add(time.Second)})
	if err != nil || len(filtered.Items) != 1 || filtered.Items[0].ID != first.ID {
		t.Fatal(filtered, err)
	}
	excluded, err := service.List(context.Background(), ledger.Query{To: first.OccurredAt})
	if err != nil || len(excluded.Items) != 0 {
		t.Fatal("to must be exclusive", excluded, err)
	}
	data, err := service.ExportCSV(context.Background(), ledger.Query{WorkerID: first.WorkerID})
	if err != nil {
		t.Fatal(err)
	}
	rows, err := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(data, []byte("\xef\xbb\xbf")))).ReadAll()
	if err != nil || len(rows) != 4 || rows[1][14] != "'=SUM(1,2)\n人工备注" || rows[1][2] != ledger.ModeSimulated || rows[1][3] != "true" {
		t.Fatal(rows, err)
	}
	if _, err := service.ExportCSV(context.Background(), ledger.Query{Before: cursor}); !errors.Is(err, ledger.ErrInvalidInput) {
		t.Fatal("partial export accepted", err)
	}
	for _, bad := range []string{"not-base64", base64.RawURLEncoding.EncodeToString([]byte(`{"id":"a","occurredAt":"2026-10-05T12:00:00Z"} {}`))} {
		if _, err := ledger.DecodeCursor(bad); !errors.Is(err, ledger.ErrInvalidInput) {
			t.Fatal(bad, err)
		}
	}
	for _, query := range []ledger.Query{{Limit: 201}, {Limit: -1}, {Mode: "production"}, {From: first.OccurredAt, To: first.OccurredAt}, {Kind: "unknown"}, {Status: "pending"}, {Channel: "unknown"}} {
		if _, err := service.List(context.Background(), query); !errors.Is(err, ledger.ErrInvalidInput) {
			t.Fatal(query, err)
		}
	}
	if !strings.Contains(string(data), "amount_cents") {
		t.Fatal("export currency units missing")
	}
}

type oversizedStore struct{ *ledger.Memory }

func (store oversizedStore) Snapshot(context.Context, ledger.Query, int) ([]ledger.Journal, error) {
	return make([]ledger.Journal, ledger.MaxExportJournals+1), nil
}
func TestExportNeverSilentlyTruncates(t *testing.T) {
	_, err := ledger.NewService(oversizedStore{ledger.NewMemory()}).ExportCSV(context.Background(), ledger.Query{})
	if !errors.Is(err, ledger.ErrExportTooLarge) {
		t.Fatal(err)
	}
}
