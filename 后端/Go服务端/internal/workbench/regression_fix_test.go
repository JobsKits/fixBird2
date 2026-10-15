package workbench

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
)

func fixRequest(t *testing.T, s *Service, actor, method, path, body, key string) *httptest.ResponseRecorder {
	t.Helper()
	token, _, err := s.login(actor, "Demo-Repair-2026!", "fix-test")
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("Authorization", "Bearer "+token)
	r.Header.Set("Idempotency-Key", key)
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}

func TestExportDownloadAuditDurableAndFailClosed(t *testing.T) {
	s, p := testService(t)
	export := fixRequest(t, s, "admin", "GET", "/api/v38/export", "", "")
	if export.Code != 200 {
		t.Fatal(export.Code)
	}
	download := fixRequest(t, s, "customer", "GET", "/api/v38/orders/wo_settling/evidence/file_report", "", "")
	if download.Code != 200 {
		t.Fatal(download.Code)
	}
	denied := fixRequest(t, s, "qc", "GET", "/api/v38/export", "", "")
	if denied.Code != 403 {
		t.Fatal(denied.Code)
	}
	if len(s.state.Audit) != 3 || s.state.Audit[0].Type != "export" || len(s.state.Audit[0].ResourceIDs) != 8 || s.state.Audit[1].Resource != "wo_settling/file_report" || s.state.Audit[2].Result != "denied" {
		t.Fatal("missing audit scope/results")
	}
	restarted, err := New(p)
	if err != nil || len(restarted.state.Audit) != 3 {
		t.Fatalf("audit restart: %v", err)
	}
	if w := fixRequest(t, restarted, "finance", "GET", "/api/v38/audit", "", ""); w.Code != 403 {
		t.Fatal("audit exposed to non-admin")
	}
	w := fixRequest(t, restarted, "admin", "GET", "/api/v38/audit?page=1&pageSize=2", "", "")
	if w.Code != 200 || !bytes.Contains(w.Body.Bytes(), []byte(`"total":3`)) {
		t.Fatal("audit pagination missing")
	}
	p.fail = true
	w = fixRequest(t, s, "admin", "GET", "/api/v38/export", "", "")
	if w.Code != 500 || bytes.Contains(w.Body.Bytes(), []byte("wo_quote")) {
		t.Fatal("audit failure released private export")
	}
	w = fixRequest(t, s, "customer", "GET", "/api/v38/orders/wo_settling/evidence/file_report", "", "")
	if w.Code != 500 || bytes.Contains(w.Body.Bytes(), []byte("无真实客户资料")) {
		t.Fatal("audit failure released original")
	}
}

func TestAccountStatusAuditAtomicAndIdempotent(t *testing.T) {
	s, p := testService(t)
	body := `{"status":"disabled","reason":"合成交接依据"}`
	w := fixRequest(t, s, "admin", "POST", "/api/v38/accounts/customer/status", body, "status-fix")
	if w.Code != 200 {
		t.Fatal(w.Code, w.Body.String())
	}
	if len(s.state.Audit) != 1 {
		t.Fatal("account history missing")
	}
	event := s.state.Audit[0]
	if event.ActorID != "admin" || event.Resource != "customer" || event.Reason != "合成交接依据" || event.Before != "active" || event.After != "disabled" || event.AuthBefore != 1 || event.AuthAfter != 2 {
		t.Fatalf("incomplete status history %+v", event)
	}
	w = fixRequest(t, s, "admin", "POST", "/api/v38/accounts/customer/status", body, "status-fix")
	if w.Code != 200 || len(s.state.Audit) != 1 {
		t.Fatal("duplicate status audit")
	}
	restarted, err := New(p)
	if err != nil || restarted.state.Audit[0].Reason != event.Reason {
		t.Fatal("status reason lost on restart")
	}
	p.fail = true
	w = fixRequest(t, s, "admin", "POST", "/api/v38/accounts/customer/status", `{"status":"active","reason":"合成恢复依据"}`, "failed-status")
	if w.Code != 500 || testActor(s, "customer").Status != "disabled" || len(s.state.Audit) != 1 {
		t.Fatal("failed audit/status save partially committed")
	}
}

func TestCompactIdempotencyBeyondOldCapacityAndRestart(t *testing.T) {
	s, p := testService(t)
	for i := 0; i < 10000; i++ {
		s.state.Requests[fmt.Sprintf("old-key-%d", i)] = CachedRequest{}
	}
	actor := testActor(s, "warehouse")
	input := PurchaseInput{Supplier: "supplier", PartID: "part-board", Quantity: 2, UnitCents: 1000, Note: "合成批准采购"}
	raw, _ := json.Marshal(input)
	fn := func(st *State) (any, error) { return s.createPurchase(st, actor, input) }
	first, _, err := s.transact(actor, "POST /api/v38/purchases", "purchase-after-capacity", raw, 201, fn)
	if err != nil || len(s.state.Requests) != 10001 {
		t.Fatalf("capacity still blocks new work: %v", err)
	}
	key := "warehouse:POST /api/v38/purchases:purchase-after-capacity"
	if len(s.state.Requests[key].Body) > 90 || bytes.Contains(s.state.Requests[key].Body, []byte("合成批准采购")) {
		t.Fatal("response graph retained")
	}
	if s.capacity()["warning"] != true {
		t.Fatal("capacity warning missing")
	}
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	before := len(restarted.state.Purchases)
	second, _, err := restarted.transact(testActor(restarted, "warehouse"), "POST /api/v38/purchases", "purchase-after-capacity", raw, 201, func(st *State) (any, error) { t.Fatal("old key executed again"); return nil, nil })
	if err != nil || !bytes.Equal(first, second) || len(restarted.state.Purchases) != before {
		t.Fatal("compact retry did not preserve deduplication")
	}
	_, _, err = restarted.transact(testActor(restarted, "warehouse"), "POST /api/v38/purchases", "purchase-after-capacity", []byte(`{"different":true}`), 201, fn)
	expectCode(t, err, "idempotency_conflict")
}

func TestLegacyResponseCompactionPreservesKeysAndAuthorization(t *testing.T) {
	s, p := testService(t)
	order := testOrder(t, s, "wo_quote")
	order.Evidence = append(order.Evidence, Evidence{ID: "historical-only", Text: "synthetic old private text"})
	body, _ := json.Marshal(order)
	raw := []byte(`{"legacy":true}`)
	key := "customer:POST /orders/wo_quote/actions:legacy"
	// Use the normal transaction once to obtain its request digest.
	_, _, err := s.transact(testActor(s, "customer"), "POST /orders/wo_quote/actions", "legacy", raw, 200, func(st *State) (any, error) { return order, nil })
	if err != nil {
		t.Fatal(err)
	}
	request := s.state.Requests[key]
	request.Body = body
	s.state.Requests[key] = request
	snapshot, _ := json.Marshal(s.state)
	if err = p.Save(snapshot); err != nil {
		t.Fatal(err)
	}
	restarted, err := New(p)
	if err != nil || len(restarted.state.Requests) != 1 || bytes.Contains(restarted.state.Requests[key].Body, []byte("synthetic old private text")) {
		t.Fatal("legacy archive migration lost key or retained body")
	}
	mustAct(t, restarted, "dispatcher", "wo_quote", "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成撤权"})
	_, _, err = restarted.transact(testActor(restarted, "customer"), "POST /orders/wo_quote/actions", "legacy", raw, 200, func(st *State) (any, error) { t.Fatal("revoked retry executed"); return nil, nil })
	expectCode(t, err, "not_found")
}

func TestPagedBootstrapOmitsGraphsAndKeepsGlobalMetrics(t *testing.T) {
	s, _ := testService(t)
	base := testOrder(t, s, "wo_quote")
	base.Quote.Signature = strings.Repeat("SYNTHETIC-LARGE-SIGNATURE", 10000)
	base.Events = []Event{{ID: "event-test", Note: "SYNTHETIC-HISTORICAL-GRAPH"}}
	base.Evidence = []Evidence{{ID: "file-test", Text: "SYNTHETIC-FILE-BODY"}}
	s.state.Orders = make([]Order, 1000)
	for i := range s.state.Orders {
		order := base
		order.ID = fmt.Sprintf("wo_scale_%d", i)
		order.Number = fmt.Sprintf("SCALE-%04d", i)
		s.state.Orders[i] = order
	}
	w := fixRequest(t, s, "admin", "GET", "/api/v38/bootstrap", "", "")
	if w.Code != 200 || w.Body.Len() > 180000 || bytes.Contains(w.Body.Bytes(), []byte("SYNTHETIC-LARGE-SIGNATURE")) || bytes.Contains(w.Body.Bytes(), []byte("SYNTHETIC-HISTORICAL-GRAPH")) || bytes.Contains(w.Body.Bytes(), []byte("SYNTHETIC-FILE-BODY")) {
		t.Fatalf("bootstrap still transfers graph, bytes=%d", w.Body.Len())
	}
	var response struct {
		Orders  []Order          `json:"orders"`
		Metrics map[string]int64 `json:"metrics"`
		Page    struct {
			Total int `json:"total"`
		} `json:"orderPage"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if len(response.Orders) != 30 || response.Page.Total != 1000 || response.Metrics["openCount"] != 1000 || response.Metrics["remainingCents"] != 128000000 {
		t.Fatal("page totals or global metrics incorrect")
	}
	second := s.queryOrders(testActor(s, "admin"), OrderQuery{Page: 2, PageSize: 30})
	if len(second.Items) != 30 || second.Items[0].ID == response.Orders[0].ID || second.TotalPages != 34 || !second.Items[0].IsSummary {
		t.Fatal("pagination failed")
	}
	t.Logf("1000 synthetic orders: bootstrap bytes=%d, first page=%d, global total=%d", w.Body.Len(), len(response.Orders), response.Page.Total)
}

func TestPendingCashFiltersRespectFinancialReadScope(t *testing.T) {
	s, _ := testService(t)
	mustAct(t, s, "engineer", "wo_quote", "cash", map[string]any{"amountCents": 1000, "kind": "receipt", "purpose": "合成现金", "receipt": "SYNTHETIC-CASH", "occurredAt": nowString(s.now())})
	for _, role := range []string{"qc", "warehouse", "customer"} {
		page := s.queryOrders(testActor(s, role), OrderQuery{Page: 1, PageSize: 30, Filter: "cash_pending"})
		if page.Total != 0 {
			t.Fatalf("%s inferred another collector's pending cash", role)
		}
	}
	page := s.queryOrders(testActor(s, "engineer"), OrderQuery{Page: 1, PageSize: 30, Payment: "pending"})
	if page.Total != 1 || page.Items[0].Summary.PendingCashCents != 1000 {
		t.Fatal("engineer's own pending cash unavailable")
	}
}

func TestReadAuthorizationRecheckedAfterRevocation(t *testing.T) {
	s, _ := testService(t)
	actor := testActor(s, "customer")
	for i := range s.state.Accounts {
		if s.state.Accounts[i].Actor.ID == actor.ID {
			s.state.Accounts[i].Actor.AuthVersion++
		}
	}
	_, err := s.currentActorLocked(actor)
	expectCode(t, err, "unauthenticated")
}
