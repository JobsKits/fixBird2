package workbench

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func permissionsFixture() Order {
	return Order{
		ID: "permissions-order", Number: "TEST-PERMISSIONS", Version: 1,
		CompanyID: "company-a", CustomerID: "customer", AssigneeID: "engineer",
		Type: "mail", Status: "repairing", Remark: "internal-remark-sentinel",
		Description: "repair-description-sentinel", CustomerNote: "public-customer-note",
		Costs: []Cost{
			{ID: "cost-engineer", OwnerID: "engineer", AmountCents: 100, Note: "own-engineer-expense"},
			{ID: "cost-warehouse", OwnerID: "warehouse", AmountCents: 200, Note: "own-warehouse-expense"},
			{ID: "cost-finance", OwnerID: "finance", AmountCents: 300, Note: "private-finance-cost-sentinel"},
		},
		Commissions: []Commission{{ID: "commission", Person: "private-commission-person-sentinel", AmountCents: 400, Note: "private-commission-note-sentinel"}},
		Cash: []Cash{
			{ID: "verified", AmountCents: 500, Collector: "finance", Verified: true, VerifiedBy: "admin", Kind: "receipt"},
			{ID: "pending-engineer", AmountCents: 600, Collector: "engineer", Kind: "receipt"},
			{ID: "pending-warehouse", AmountCents: 700, Collector: "warehouse", Kind: "receipt"},
			{ID: "pending-finance", AmountCents: 800, Collector: "finance", Kind: "receipt"},
		},
		Visits:    []Visit{{ID: "visit", FeeMemo: "internal-visit-fee-sentinel"}},
		Outsource: []Outsource{{ID: "outsource", Note: "internal-outsource-note-sentinel"}},
		Obligations: []Task{
			{ID: "finance-task", OwnerID: "finance", Title: "private-finance-task-sentinel"},
			{ID: "engineer-task", OwnerID: "engineer", Title: "own-engineer-task"},
		},
		Evidence: []Evidence{
			{ID: "public-report", Name: "published-report", Text: "public-repair-report", Stage: "settling", Public: true, UploaderID: "dispatcher"},
			{ID: "engineer-own", Name: "own-expense-evidence", Text: "own-expense-evidence", Stage: "settling", UploaderID: "engineer"},
			{ID: "repair-report", Name: "repair-report", Text: "repair-test-results", Stage: "repairing", UploaderID: "dispatcher"},
			{ID: "warehouse-receipt", Name: "warehouse-receipt", Text: "warehouse-receipt", Stage: "pending_arrangement", UploaderID: "dispatcher"},
			{ID: "private-finance-file", Name: "private-finance-file-sentinel", Text: "private-finance-content-sentinel", Stage: "settling", UploaderID: "finance"},
		},
		Events: []Event{
			{ID: "own-cost", Type: "cost", ActorID: "engineer", Note: "own-engineer-expense", Internal: true},
			{ID: "other-cost", Type: "cost", ActorID: "finance", Note: "private-finance-cost-sentinel", Internal: true},
			{ID: "commission", Type: "commission", ActorID: "finance", Note: "private-commission-note-sentinel", Internal: true},
			{ID: "commission-settled", Type: "settle_commission", ActorID: "finance", Note: "private-commission-settlement-sentinel", Internal: true},
			{ID: "approval", Type: "approve_cost", ActorID: "finance", Note: "private-financial-approval-sentinel", Internal: true},
			{ID: "invoice", Type: "invoice", ActorID: "finance", Note: "private-invoice-accounting-sentinel"},
			{ID: "invoice-void", Type: "void_invoice", ActorID: "finance", Note: "private-invoice-correction-sentinel"},
			{ID: "adjust", Type: "adjust_receivable", ActorID: "finance", Note: "private-receivable-approval-sentinel"},
			{ID: "documents", Type: "documents", ActorID: "finance", Note: "private-document-ground-sentinel"},
			{ID: "cash-registered", Type: "cash", ActorID: "finance", Note: "private-cash-registration-sentinel", Internal: true},
			{ID: "verify", Type: "verify_cash", ActorID: "finance", Note: "private-cash-verification-sentinel"},
			{ID: "handover", Type: "handover_cash", ActorID: "finance", Note: "private-cash-handover-sentinel", Internal: true},
			{ID: "remark", Type: "remark", ActorID: "dispatcher", Note: "internal-remark-sentinel", Internal: true},
			{ID: "outsource", Type: "outsource", ActorID: "dispatcher", Note: "internal-outsource-note-sentinel", Internal: true},
			{ID: "report", Type: "report", ActorID: "engineer", Note: "repair-test-results"},
		},
		Summary: Summary{
			PendingCashCents: 2100, CollectedCents: 500,
			Missing:  []string{"成本待审核", "提成待结算", "现金待财务核实", "现金内部交接未完成", "待办：private-finance-task-sentinel", "客户账款未收齐"},
			NextTask: "成本待审核；提成待结算；现金待财务核实；现金内部交接未完成；待办：private-finance-task-sentinel；客户账款未收齐",
		},
	}
}

func TestFilterOrderFieldsRoleMatrix(t *testing.T) {
	cases := []struct {
		role        string
		costIDs     []string
		commissions int
		cashCount   int
		pending     int64
	}{
		{"admin", []string{"cost-engineer", "cost-warehouse", "cost-finance"}, 1, 4, 2100},
		{"dispatcher", []string{"cost-engineer", "cost-warehouse", "cost-finance"}, 1, 4, 2100},
		{"finance", []string{"cost-engineer", "cost-warehouse", "cost-finance"}, 1, 4, 2100},
		{"engineer", []string{"cost-engineer"}, 0, 2, 600},
		{"warehouse", []string{"cost-warehouse"}, 0, 2, 700},
		{"qc", []string{}, 0, 1, 0},
		{"customer", []string{}, 0, 1, 0},
		{"outsource", []string{}, 0, 1, 0},
		{"supplier", []string{}, 0, 1, 0},
	}
	for _, tc := range cases {
		t.Run(tc.role, func(t *testing.T) {
			actor := Actor{ID: tc.role, Role: tc.role, CompanyID: "company-a"}
			order := permissionsFixture()
			filterOrderFields(&order, actor)
			if len(order.Costs) != len(tc.costIDs) || len(order.Commissions) != tc.commissions || len(order.Cash) != tc.cashCount || order.Summary.PendingCashCents != tc.pending {
				t.Fatalf("unexpected financial fields: costs=%d commissions=%d cash=%d pending=%d", len(order.Costs), len(order.Commissions), len(order.Cash), order.Summary.PendingCashCents)
			}
			for i, id := range tc.costIDs {
				if order.Costs[i].ID != id {
					t.Fatalf("cost %s exposed instead of %s", order.Costs[i].ID, id)
				}
			}
			if !readsFinancialDetails(actor) {
				for _, event := range order.Events {
					if strings.Contains(event.Note, "private-") {
						t.Fatalf("financial event %s leaked its note", event.Type)
					}
				}
				if order.Cash[0].Collector != "" || order.Cash[0].VerifiedBy != "" {
					t.Fatal("other collector's internal identities leaked")
				}
				if internal(actor) && (strings.Contains(order.Summary.NextTask, "提成") || strings.Contains(order.Summary.NextTask, "private-finance-task")) {
					t.Fatal("financial task summary leaked")
				}
			}
			if order.Description != "repair-description-sentinel" || order.CustomerNote != "public-customer-note" || order.Summary.CollectedCents != 500 {
				t.Fatal("customer-facing fulfillment facts changed")
			}
		})
	}
}

func TestCanReadEvidenceRoleStageMatrix(t *testing.T) {
	order := permissionsFixture()
	stages := []string{"pending_intake", "pending_arrangement", "diagnosis_quotation", "pending_customer_confirmation", "pending_execution", "repairing", "pending_quality_check", "pending_delivery", "pending_acceptance", "settling", "pending_completion", "completed", ""}
	allowed := map[string]map[string]bool{
		"engineer":  {"pending_arrangement": true, "diagnosis_quotation": true, "pending_customer_confirmation": true, "pending_execution": true, "repairing": true, "pending_quality_check": true, "pending_delivery": true},
		"warehouse": {"pending_arrangement": true, "pending_execution": true, "pending_quality_check": true, "pending_delivery": true, "pending_acceptance": true},
		"qc":        {"diagnosis_quotation": true, "repairing": true, "pending_quality_check": true},
	}
	for role, stagesAllowed := range allowed {
		actor := Actor{ID: role, Role: role}
		for _, stage := range stages {
			evidence := Evidence{ID: "private-stage", UploaderID: "dispatcher", Stage: stage}
			if got := canReadEvidence(order, evidence, actor); got != stagesAllowed[stage] {
				t.Errorf("%s stage %q: got %v wanted %v", role, stage, got, stagesAllowed[stage])
			}
		}
	}
	for _, role := range []string{"admin", "dispatcher", "finance", "engineer", "warehouse", "qc", "customer"} {
		actor := Actor{ID: role, Role: role, CompanyID: "company-a"}
		for _, own := range []bool{false, true} {
			evidence := Evidence{ID: "public-or-own", UploaderID: "someone-else", Stage: "settling", Public: !own}
			if own {
				evidence.UploaderID = actor.ID
			}
			if !canReadEvidence(order, evidence, actor) {
				t.Errorf("%s lost public=%v / own=%v evidence", role, !own, own)
			}
			evidence.Deleted = true
			if canReadEvidence(order, evidence, actor) {
				t.Errorf("%s can read deleted evidence", role)
			}
		}
	}
	public := Evidence{Public: true, UploaderID: "customer-peer"}
	for _, actor := range []Actor{{ID: "customer-peer", Role: "customer", CompanyID: "company-a"}, {ID: "engineer-2", Role: "engineer"}, {ID: "supplier", Role: "supplier"}, {ID: "unknown", Role: "unknown"}} {
		if canReadEvidence(order, public, actor) {
			t.Errorf("unauthorized %s bypassed order access through public/own evidence", actor.ID)
		}
	}
}

func TestCanReadEvidenceUnpublishedFinancialReferences(t *testing.T) {
	order := permissionsFixture()
	order.Documents.Files = []string{"private-document"}
	order.Invoices = []Invoice{{ID: "invoice", Files: []string{"private-invoice"}}}
	for _, id := range []string{"private-document", "private-invoice"} {
		evidence := Evidence{ID: id, UploaderID: "finance", Stage: "pending_quality_check"}
		for _, role := range []string{"engineer", "warehouse", "qc"} {
			actor := Actor{ID: role, Role: role}
			if canReadEvidence(order, evidence, actor) {
				t.Errorf("%s can read unpublished financial reference %s", role, id)
			}
			evidence.Public = true
			if !canReadEvidence(order, evidence, actor) {
				t.Errorf("%s cannot read published customer document %s", role, id)
			}
			evidence.Public = false
		}
	}
}

// These entry points must continue to share Service.view, including exported
// data and a cached write response recomputed for the current reader.
func TestFieldPermissionsHTTPViewsAndDownloads(t *testing.T) {
	s, _ := testService(t)
	s.state.Orders = []Order{permissionsFixture()}
	handler := s.Handler("")
	for _, role := range []string{"admin", "dispatcher", "finance", "engineer", "warehouse", "qc", "customer"} {
		t.Run(role, func(t *testing.T) {
			token, actor, err := s.login(role, "Demo-Repair-2026!", "permission-test")
			if err != nil {
				t.Fatal(err)
			}
			get := func(path string) *httptest.ResponseRecorder {
				r := httptest.NewRequest(http.MethodGet, path, nil)
				r.Header.Set("Authorization", "Bearer "+token)
				w := httptest.NewRecorder()
				handler.ServeHTTP(w, r)
				return w
			}
			for _, path := range []string{"/api/v38/orders", "/api/v38/orders/permissions-order", "/api/v38/bootstrap", "/api/v38/export"} {
				w := get(path)
				if path == "/api/v38/export" && role != "admin" && role != "dispatcher" && role != "finance" && role != "customer" {
					if w.Code != http.StatusForbidden {
						t.Fatalf("%s can export: HTTP %d", role, w.Code)
					}
					continue
				}
				if w.Code != http.StatusOK {
					t.Fatalf("%s: HTTP %d", path, w.Code)
				}
				var document any
				if err := json.Unmarshal(w.Body.Bytes(), &document); err != nil {
					t.Fatal(err)
				}
				if readsFinancialDetails(actor) {
					if (path == "/api/v38/orders/permissions-order" || path == "/api/v38/export") && (!strings.Contains(w.Body.String(), "private-finance-cost-sentinel") || !strings.Contains(w.Body.String(), "private-commission-note-sentinel")) {
						t.Fatalf("%s lost financial details in %s", role, path)
					}
					continue
				}
				for _, secret := range []string{"private-finance-cost-sentinel", "private-commission-person-sentinel", "private-commission-note-sentinel", "private-financial-approval-sentinel", "private-invoice-accounting-sentinel", "private-cash-verification-sentinel", "private-finance-file-sentinel", "private-finance-content-sentinel", "private-finance-task-sentinel"} {
					if strings.Contains(w.Body.String(), secret) {
						t.Fatalf("%s leaked %s in %s", role, secret, path)
					}
				}
				if role == "engineer" && path == "/api/v38/orders/permissions-order" && !strings.Contains(w.Body.String(), "own-engineer-expense") {
					t.Fatalf("engineer's own expense missing from %s", path)
				}
				if (path == "/api/v38/orders/permissions-order" || path == "/api/v38/export") && !strings.Contains(w.Body.String(), "repair-test-results") {
					t.Fatalf("repair report missing from %s", path)
				}
			}
			if w := get("/api/v38/orders/permissions-order/evidence/public-report"); w.Code != http.StatusOK {
				t.Fatalf("public report download: HTTP %d", w.Code)
			}
			private := get("/api/v38/orders/permissions-order/evidence/private-finance-file")
			wanted := http.StatusNotFound
			if readsFinancialDetails(actor) {
				wanted = http.StatusOK
			}
			if private.Code != wanted {
				t.Fatalf("private finance download: HTTP %d wanted %d", private.Code, wanted)
			}
			if !readsFinancialDetails(actor) {
				r := httptest.NewRequest(http.MethodPost, "/api/v38/orders/permissions-order/actions", strings.NewReader(`{"type":"commission","version":1,"payload":{}}`))
				r.Header.Set("Authorization", "Bearer "+token)
				r.Header.Set("Idempotency-Key", "permission-denied-"+role)
				w := httptest.NewRecorder()
				handler.ServeHTTP(w, r)
				if w.Code != http.StatusForbidden || strings.Contains(w.Body.String(), "private-") {
					t.Fatalf("financial action error leaked data or allowed %s: HTTP %d", role, w.Code)
				}
			}
		})
	}
	for _, id := range []string{"customer-peer", "customer-b", "outsource"} {
		token, _, err := s.login(id, "Demo-Repair-2026!", "permission-test")
		if err != nil {
			t.Fatal(err)
		}
		for _, path := range []string{"/api/v38/orders/permissions-order", "/api/v38/orders/permissions-order/evidence/public-report"} {
			r := httptest.NewRequest(http.MethodGet, path, nil)
			r.Header.Set("Authorization", "Bearer "+token)
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, r)
			if w.Code != http.StatusNotFound {
				t.Errorf("%s accessed unauthorized order/file: HTTP %d", id, w.Code)
			}
		}
	}
}
