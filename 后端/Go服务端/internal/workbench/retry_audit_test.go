package workbench

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestReviewCompactedCashAndInventoryRetriesAfterRestart(t *testing.T) {
	s, p := testService(t)
	original := testOrder(t, s, "wo_quote")
	cash := map[string]any{"amountCents": 1000, "kind": "receipt", "purpose": "独立合成收款诊断", "receipt": "SYNTHETIC-REVIEW", "occurredAt": nowString(s.now())}
	first, err := testActVersion(s, testActor(s, "engineer"), original.ID, "cash", cash, original.Version, "cash-review-once")
	if err != nil {
		t.Fatal(err)
	}
	mustAct(t, s, "finance", original.ID, "verify_cash", map[string]any{"cashId": first.Cash[len(first.Cash)-1].ID})
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	replayed, err := testActVersion(restarted, testActor(restarted, "engineer"), original.ID, "cash", cash, original.Version, "cash-review-once")
	if err != nil || len(replayed.Cash) != 1 || replayed.Summary.CollectedCents != 1000 {
		t.Fatalf("cash replay changed financial facts: %v", err)
	}
	warehouse := testActor(restarted, "warehouse")
	loanInput := LoanInput{PartID: "part-board", Quantity: 2, BorrowerID: "engineer", DueAt: nowString(s.now().Add(24 * time.Hour)), Note: "独立合成库存诊断"}
	raw, _ := json.Marshal(loanInput)
	borrowBody, _, err := restarted.transact(warehouse, "POST /api/v38/loans", "borrow-review-once", raw, 201, func(st *State) (any, error) { return restarted.createLoan(st, warehouse, loanInput) })
	if err != nil {
		t.Fatal(err)
	}
	var loan Loan
	_ = json.Unmarshal(borrowBody, &loan)
	returnPayload, _ := json.Marshal(loanPayload{Quantity: 1, Condition: "good"})
	returnAction := Action{Type: "return", Version: loan.Version, Payload: returnPayload}
	returnRaw, _ := json.Marshal(returnAction)
	_, _, err = restarted.transact(warehouse, "POST /api/v38/loans/"+loan.ID+"/actions", "return-review-once", returnRaw, 200, func(st *State) (any, error) { return restarted.loanAction(st, warehouse, loan.ID, returnAction) })
	if err != nil {
		t.Fatal(err)
	}
	beforePart := restarted.state.Parts[0]
	again, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	for _, request := range []struct {
		path, key string
		raw       []byte
	}{{"POST /api/v38/loans", "borrow-review-once", raw}, {"POST /api/v38/loans/" + loan.ID + "/actions", "return-review-once", returnRaw}} {
		_, _, err := again.transact(testActor(again, "warehouse"), request.path, request.key, request.raw, 200, func(st *State) (any, error) { t.Fatal("cached inventory transaction executed twice"); return nil, nil })
		if err != nil {
			t.Fatal(err)
		}
	}
	if again.state.Parts[0] != beforePart || len(again.state.Loans) != 1 || again.state.Loans[0].Outstanding != 1 {
		t.Fatal("compacted inventory retries changed conservation")
	}
	input := PurchaseInput{Supplier: "supplier", PartID: "part-board", Quantity: 4, UnitCents: 1000, Note: "独立合成采购诊断"}
	raw, _ = json.Marshal(input)
	actor := testActor(again, "warehouse")
	result, _, err := again.transact(actor, "POST /api/v38/purchases", "purchase-review-once", raw, 201, func(st *State) (any, error) { return again.createPurchase(st, actor, input) })
	if err != nil {
		t.Fatal(err)
	}
	var purchase Purchase
	_ = json.Unmarshal(result, &purchase)
	receive := PurchaseReceive{Version: purchase.Version, Quantity: 2, Note: "合成实收数量"}
	receiveRaw, _ := json.Marshal(receive)
	path := "POST /api/v38/purchases/" + purchase.ID + "/receive"
	_, _, err = again.transact(actor, path, "purchase-receive-review", receiveRaw, 200, func(st *State) (any, error) { return again.receivePurchase(st, actor, purchase.ID, receive) })
	if err != nil {
		t.Fatal(err)
	}
	stock := again.state.Parts[0]
	final, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	_, _, err = final.transact(testActor(final, "warehouse"), path, "purchase-receive-review", receiveRaw, 200, func(st *State) (any, error) { t.Fatal("cached receive executed twice"); return nil, nil })
	if err != nil || final.state.Parts[0] != stock {
		t.Fatalf("purchase retry changed stock: %v", err)
	}
}

func TestReviewAuditFailureWithholdsDetailAndLoginCredential(t *testing.T) {
	s, p := testService(t)
	token, _, err := s.login("admin", "Demo-Repair-2026!", "review")
	if err != nil {
		t.Fatal(err)
	}
	before := len(s.state.Audit)
	p.fail = true
	r := httptest.NewRequest("GET", "/api/v38/orders/wo_quote", nil)
	r.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	if w.Code != http.StatusInternalServerError || strings.Contains(w.Body.String(), "wo_quote") || len(s.state.Audit) != before {
		t.Fatal("audit failure released detail or partially committed audit")
	}
	sessions := len(s.sessions)
	w = httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, httptest.NewRequest("POST", "/api/v38/login", strings.NewReader(`{"username":"customer","password":"Demo-Repair-2026!"}`)))
	if w.Code != http.StatusInternalServerError || strings.Contains(w.Body.String(), `"token"`) || len(s.sessions) != sessions {
		t.Fatal("failed login audit retained or returned a new credential")
	}
}

func TestReviewQueryEmptyPaginationAndHiddenPendingCashSideChannels(t *testing.T) {
	s, _ := testService(t)
	mustAct(t, s, "engineer", "wo_quote", "cash", map[string]any{"amountCents": 1000, "kind": "receipt", "purpose": "合成待核款", "receipt": "REVIEW-CASH", "occurredAt": nowString(s.now())})
	for _, role := range []string{"qc", "warehouse", "customer"} {
		for _, query := range []OrderQuery{{Page: 1, PageSize: 2, Filter: "cash_pending"}, {Page: 1, PageSize: 2, Payment: "pending"}} {
			page := s.queryOrders(testActor(s, role), query)
			if page.Total != 0 || page.TotalPages != 0 || len(page.Items) != 0 {
				t.Fatalf("%s inferred hidden pending collection", role)
			}
		}
	}
	page := s.queryOrders(testActor(s, "admin"), OrderQuery{Page: 100000, PageSize: 200})
	if len(page.Items) != 0 || page.Total != 8 || page.TotalPages != 1 {
		t.Fatal("beyond-last pagination totals inconsistent")
	}
}
