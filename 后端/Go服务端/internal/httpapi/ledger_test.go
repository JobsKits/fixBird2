package httpapi

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/ledger"
)

func ledgerHTTPFixture(t *testing.T) http.Handler {
	t.Helper()
	store := ledger.NewMemory()
	for index, suffix := range []string{"one", "two", "three"} {
		workerID := "worker-one"
		if suffix == "three" {
			workerID = "worker-three"
		}
		journal, err := ledger.NewCollection(ledger.Collection{OrderID: "order-" + suffix,
			CustomerID: "customer-" + suffix, WorkerID: workerID, SettlementID: "settlement-" + suffix,
			AmountCents: 100, WorkerShareCents: 85, PlatformFeeCents: 15,
			OccurredAt: time.Date(2026, 10, 5, 10+index, 0, 0, 0, time.UTC)})
		if err != nil {
			t.Fatal(err)
		}
		if _, err = store.Append(context.Background(), journal); err != nil {
			t.Fatal(err)
		}
	}
	server := &Server{ledgerService: ledger.NewService(store)}
	mux := http.NewServeMux()
	server.registerLedgerRoutes(mux)
	return mux
}

func ledgerHTTPRequest(handler http.Handler, method, path string, role domain.Role, id string, session bool) *httptest.ResponseRecorder {
	request := httptest.NewRequest(method, path, nil)
	// Forged legacy headers cannot override a session principal or grant session access.
	request.Header.Set("X-Actor-Role", "admin")
	request.Header.Set("X-Actor-ID", "forged-admin")
	if id != "" {
		request = request.WithContext(context.WithValue(request.Context(), principalKey{}, principal{
			Actor: domain.Actor{Role: role, ID: id}, Session: session,
		}))
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func ledgerHTTPRows(t *testing.T, response *httptest.ResponseRecorder) []ledger.Journal {
	t.Helper()
	if response.Code != http.StatusOK {
		t.Fatalf("HTTP %d: %s", response.Code, response.Body)
	}
	var rows []ledger.Journal
	if err := json.Unmarshal(response.Body.Bytes(), &rows); err != nil {
		t.Fatal(err)
	}
	return rows
}

func TestLedgerHTTPRequiresSessionAndAdminRole(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	for _, path := range []string{"/api/v1/ledger/journals", "/api/v1/ledger/summary", "/api/v1/admin/ledger/journals", "/api/v1/admin/ledger/summary", "/api/v1/admin/ledger/export.csv"} {
		for _, id := range []string{"", "customer-demo"} {
			response := ledgerHTTPRequest(handler, "GET", path, domain.RoleCustomer, id, false)
			if response.Code != http.StatusUnauthorized {
				t.Fatalf("anonymous %s returned %d", path, response.Code)
			}
		}
	}
	for _, path := range []string{"/api/v1/admin/ledger/journals", "/api/v1/admin/ledger/summary", "/api/v1/admin/ledger/export.csv"} {
		response := ledgerHTTPRequest(handler, "GET", path, domain.RoleWorker, "worker-one", true)
		if response.Code != http.StatusForbidden {
			t.Fatalf("worker admin route %s returned %d", path, response.Code)
		}
	}
}

func TestLedgerHTTPPersonalScopeCannotBeOverridden(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	for _, prefix := range []string{"/api/v1/ledger", "/api/v1/me/ledger"} {
		customer := ledgerHTTPRows(t, ledgerHTTPRequest(handler, "GET", prefix+"/journals", domain.RoleCustomer, "customer-one", true))
		if len(customer) != 1 || customer[0].OrderID != "order-one" {
			t.Fatalf("customer scope: %+v", customer)
		}
		worker := ledgerHTTPRows(t, ledgerHTTPRequest(handler, "GET", prefix+"/journals", domain.RoleWorker, "worker-one", true))
		if len(worker) != 2 || worker[0].WorkerID != "worker-one" || worker[1].WorkerID != "worker-one" {
			t.Fatalf("worker scope: %+v", worker)
		}
		for _, owner := range []struct {
			role domain.Role
			id   string
			path string
		}{{domain.RoleCustomer, "customer-one", "customerId=customer-three"}, {domain.RoleWorker, "worker-one", "workerId=worker-three"}} {
			response := ledgerHTTPRequest(handler, "GET", prefix+"/journals?"+owner.path, owner.role, owner.id, true)
			if response.Code != http.StatusForbidden {
				t.Fatalf("foreign scope override returned %d", response.Code)
			}
		}
		response := ledgerHTTPRequest(handler, "GET", prefix+"/summary", domain.RoleAdmin, "admin-one", true)
		if response.Code != http.StatusForbidden {
			t.Fatalf("admin must use explicit admin scope, got %d", response.Code)
		}
	}
}

func TestLedgerHTTPPaginationAndSummaryHaveSameFilter(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	path := "/api/v1/admin/ledger/journals?workerId=worker-one&limit=1"
	first := ledgerHTTPRequest(handler, "GET", path, domain.RoleAdmin, "admin-one", true)
	rows := ledgerHTTPRows(t, first)
	cursor := first.Header().Get("X-Next-Cursor")
	if len(rows) != 1 || cursor == "" || rows[0].OrderID != "order-two" {
		t.Fatalf("first page %s cursor %q", first.Body, cursor)
	}
	second := ledgerHTTPRequest(handler, "GET", path+"&cursor="+cursor, domain.RoleAdmin, "admin-one", true)
	rows = ledgerHTTPRows(t, second)
	if len(rows) != 1 || rows[0].OrderID != "order-one" || second.Header().Get("X-Next-Cursor") != "" {
		t.Fatalf("second page %s", second.Body)
	}
	response := ledgerHTTPRequest(handler, "GET", "/api/v1/admin/ledger/summary?workerId=worker-one&limit=1&cursor="+cursor, domain.RoleAdmin, "admin-one", true)
	var summary ledger.Summary
	if response.Code != http.StatusOK || json.Unmarshal(response.Body.Bytes(), &summary) != nil || summary.JournalCount != 2 || summary.CollectedCents != 200 || summary.WorkerPayableCents != 170 || summary.Scope != "filtered_movements" {
		t.Fatalf("summary must cover all filter matches, not current page: %s", response.Body)
	}
	personal := ledgerHTTPRequest(handler, "GET", "/api/v1/ledger/summary", domain.RoleCustomer, "customer-one", true)
	if json.Unmarshal(personal.Body.Bytes(), &summary) != nil || summary.JournalCount != 1 || summary.CollectedCents != 100 {
		t.Fatalf("personal summary scope: %s", personal.Body)
	}
}

func TestLedgerHTTPActualModeDoesNotExposeSimulatedJournals(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	response := ledgerHTTPRequest(handler, "GET", "/api/v1/admin/ledger/journals?mode=actual", domain.RoleAdmin, "admin-one", true)
	if rows := ledgerHTTPRows(t, response); len(rows) != 0 || response.Body.String() != "[]\n" {
		t.Fatalf("actual mode contains simulated data: %s", response.Body)
	}
	response = ledgerHTTPRequest(handler, "GET", "/api/v1/admin/ledger/summary?mode=actual", domain.RoleAdmin, "admin-one", true)
	var summary ledger.Summary
	if json.Unmarshal(response.Body.Bytes(), &summary) != nil || summary.Mode != ledger.ModeActual || summary.Simulated || summary.JournalCount != 0 {
		t.Fatalf("actual summary: %s", response.Body)
	}
}

func TestLedgerHTTPRejectsInvalidFilterAndDoesNotExposeMutation(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	for _, filter := range []string{"limit=201", "limit=oops", "cursor=not-a-cursor", "mode=real", "from=bad", "from=2026-10-05T12:00:00Z&to=2026-10-05T12:00:00Z"} {
		response := ledgerHTTPRequest(handler, "GET", "/api/v1/admin/ledger/journals?"+filter, domain.RoleAdmin, "admin-one", true)
		if response.Code != http.StatusBadRequest {
			t.Fatalf("invalid filter %q returned %d: %s", filter, response.Code, response.Body)
		}
	}
	for _, method := range []string{"POST", "DELETE", "PATCH"} {
		response := ledgerHTTPRequest(handler, method, "/api/v1/admin/ledger/journals", domain.RoleAdmin, "admin-one", true)
		if response.Code != http.StatusMethodNotAllowed {
			t.Fatalf("unexpected ledger mutation route %s: %d", method, response.Code)
		}
	}
}

func TestLedgerHTTPCSVExportsEntireFilterAsImmutableEntries(t *testing.T) {
	handler := ledgerHTTPFixture(t)
	response := ledgerHTTPRequest(handler, "GET", "/api/v1/admin/ledger/export.csv?customerId=customer-one&limit=1", domain.RoleAdmin, "admin-one", true)
	if response.Code != http.StatusOK || !strings.HasPrefix(response.Body.String(), "\ufeff") || response.Header().Get("Cache-Control") != "no-store" || response.Header().Get("Content-Type") != "text/csv; charset=utf-8" {
		t.Fatalf("CSV response: %d %v %s", response.Code, response.Header(), response.Body)
	}
	rows, err := csv.NewReader(strings.NewReader(strings.TrimPrefix(response.Body.String(), "\ufeff"))).ReadAll()
	if err != nil || len(rows) != 4 {
		t.Fatalf("CSV expected one header + three balanced entries: %v %+v", err, rows)
	}
	if !strings.Contains(response.Body.String(), "order-one") || strings.Contains(response.Body.String(), "order-two") || !strings.Contains(response.Body.String(), "simulated") {
		t.Fatalf("CSV lost filter or simulation labels: %s", response.Body)
	}
}
