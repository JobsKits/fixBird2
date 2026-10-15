package workbench

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
)

func secondPermissionsFixture(s *Service) Order {
	order := permissionsFixture()
	order.ID = "wo_permissions_second"
	order.OwnerID = "dispatcher"
	order.Project = "public-project-marker"
	order.Remark = "SECOND-PRIVATE-REMARK"
	order.Documents = Documents{Requirement: "none", Files: []string{}}
	order.InvoiceRequirement = "none"
	order.ReceivableCents = 1000
	s.state.Orders = []Order{order}
	return order
}

func secondPermissionToken(t *testing.T, s *Service, role string) string {
	t.Helper()
	token, _, err := s.login(role, "Demo-Repair-2026!", "isolated-second-permission-audit")
	if err != nil {
		t.Fatal(err)
	}
	return token
}

func secondPermissionHTTP(s *Service, token, method, path, key string, raw []byte) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(string(raw)))
	r.Header.Set("Authorization", "Bearer "+token)
	if key != "" {
		r.Header.Set("Idempotency-Key", key)
	}
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}

func TestSecondPassPermissionsQueryAndPendingCashScope(t *testing.T) {
	s, _ := testService(t)
	order := secondPermissionsFixture(s)
	before, _ := json.Marshal(s.state.Orders)
	for _, role := range []string{"admin", "dispatcher", "finance", "engineer", "warehouse", "qc", "customer", "customer-peer", "customer-b", "outsource", "supplier"} {
		t.Run(role, func(t *testing.T) {
			actor := testActor(s, role)
			visibleCount := 0
			if role == "admin" || role == "dispatcher" || role == "finance" || role == "engineer" || role == "warehouse" || role == "qc" || role == "customer" {
				visibleCount = 1
			}
			for _, marker := range []string{"SECOND-PRIVATE-REMARK", "private-finance-cost-sentinel", "private-commission-note-sentinel", "private-finance-content-sentinel", "private-finance-task-sentinel"} {
				got := s.queryOrders(actor, OrderQuery{Page: 1, PageSize: 1, Q: strings.ToLower(marker)})
				wanted := 0
				if marker == "SECOND-PRIVATE-REMARK" && (role == "admin" || role == "dispatcher" || role == "finance") {
					wanted = 1
				}
				if got.Total != wanted {
					t.Fatalf("q marker leaked or lost: role=%s total=%d wanted=%d", role, got.Total, wanted)
				}
			}
			for _, query := range []OrderQuery{
				{Page: 1, PageSize: 1, Q: "public-project-marker"},
				{Page: 1, PageSize: 1, Status: "repairing"},
				{Page: 1, PageSize: 1, Documents: "not_required"},
				{Page: 1, PageSize: 1, Payment: "outstanding"},
			} {
				got := s.queryOrders(actor, query)
				if got.Total != visibleCount {
					t.Fatalf("visible field filter: role=%s total=%d wanted=%d", role, got.Total, visibleCount)
				}
			}
			pending := int64(0)
			switch role {
			case "admin", "dispatcher", "finance":
				pending = 2100
			case "engineer":
				pending = 600
			case "warehouse":
				pending = 700
			}
			for _, query := range []OrderQuery{{Page: 1, PageSize: 1, Filter: "cash_pending"}, {Page: 1, PageSize: 1, Payment: "pending"}} {
				got := s.queryOrders(actor, query)
				if (pending > 0 && got.Total != 1) || (pending == 0 && got.Total != 0) {
					t.Fatalf("pending filter inferred another collector: %s", role)
				}
				if pending > 0 && got.Items[0].Summary.PendingCashCents != pending {
					t.Fatalf("pending scope amount: %s got=%d wanted=%d", role, got.Items[0].Summary.PendingCashCents, pending)
				}
			}
			if visibleCount > 0 {
				full := s.view(order, &s.state, actor)
				page := s.queryOrders(actor, OrderQuery{Page: 1, PageSize: 1})
				if full.Summary.PendingCashCents != page.Items[0].Summary.PendingCashCents || !page.Items[0].IsSummary || len(page.Items[0].Costs)+len(page.Items[0].Commissions)+len(page.Items[0].Events)+len(page.Items[0].Evidence) != 0 {
					t.Fatalf("summary/detail policy mismatch: %s", role)
				}
			}
		})
	}
	after, _ := json.Marshal(s.state.Orders)
	if string(before) != string(after) {
		t.Fatal("query/view modified stored orders")
	}
}

func TestSecondPassPermissionsGlobalMetricsAndPages(t *testing.T) {
	s, _ := testService(t)
	s.state.Orders = []Order{}
	for i := 0; i < 71; i++ {
		order := permissionsFixture()
		order.ID = "wo_second_page_" + strconv.Itoa(i)
		order.Number = "SECOND-" + strconv.Itoa(i)
		order.ReceivableCents = 1000
		order.Cash = []Cash{{ID: "cash_" + strconv.Itoa(i), Verified: true, AmountCents: 200, Kind: "receipt"}}
		order.Visits = []Visit{{ID: "visit_" + strconv.Itoa(i)}}
		order.Issues = []Task{{ID: "issue_" + strconv.Itoa(i), Title: "public issue"}}
		order.Obligations = []Task{{ID: "engineer_task_" + strconv.Itoa(i), OwnerID: "engineer", Title: "engineer duty"}, {ID: "finance_task_" + strconv.Itoa(i), OwnerID: "finance", Title: "finance duty"}}
		if i >= 41 {
			order.CustomerID, order.CompanyID, order.AssigneeID = "customer-b", "company-b", "outsource"
			order.Obligations = []Task{{ID: "qc_task_" + strconv.Itoa(i), OwnerID: "qc", Title: "quality duty"}, {ID: "finance_task_" + strconv.Itoa(i), OwnerID: "finance", Title: "finance duty"}}
		}
		s.state.Orders = append(s.state.Orders, order)
	}
	for _, row := range []struct {
		role                    string
		total, taskCount, pages int64
	}{
		{"admin", 71, 355, 3}, {"engineer", 41, 164, 2}, {"warehouse", 71, 142, 3},
		{"qc", 71, 172, 3}, {"customer", 41, 41, 2}, {"customer-b", 30, 30, 1}, {"customer-peer", 0, 0, 0},
	} {
		t.Run(row.role, func(t *testing.T) {
			actor := testActor(s, row.role)
			response := s.dashboard(actor)
			metrics := response["metrics"].(map[string]int64)
			page := response["orderPage"].(map[string]int)
			if int64(page["total"]) != row.total || int64(page["totalPages"]) != row.pages || metrics["openCount"] != row.total || metrics["remainingCents"] != row.total*800 || metrics["tasksCount"] != row.taskCount || metrics["blockedCount"] != row.total {
				t.Fatalf("global metrics/policy mismatch: %s total=%d metrics=%v", row.role, page["total"], metrics)
			}
			seen := map[string]bool{}
			for number := 1; number <= int(row.pages); number++ {
				part := s.queryOrders(actor, OrderQuery{Page: number, PageSize: 30})
				for _, order := range part.Items {
					if seen[order.ID] || !order.IsSummary {
						t.Fatal("duplicated page item or full graph")
					}
					seen[order.ID] = true
				}
			}
			if int64(len(seen)) != row.total {
				t.Fatal("pagination lost authorized orders")
			}
		})
	}
}

func TestSecondPassPermissionsDownloadAuditAndOldAuthorization(t *testing.T) {
	s, p := testService(t)
	order := secondPermissionsFixture(s)
	for _, role := range []string{"engineer", "qc", "warehouse", "customer", "customer-peer"} {
		token := secondPermissionToken(t, s, role)
		for _, file := range []string{"public-report", "private-finance-file"} {
			beforeAudit := len(s.state.Audit)
			w := secondPermissionHTTP(s, token, http.MethodGet, "/api/v38/orders/"+order.ID+"/evidence/"+file, "", nil)
			wanted := http.StatusNotFound
			if role != "customer-peer" && file == "public-report" {
				wanted = http.StatusOK
			}
			if w.Code != wanted || len(s.state.Audit) != beforeAudit+1 {
				t.Fatalf("download policy/audit: role=%s file=%s code=%d", role, file, w.Code)
			}
		}
	}
	token := secondPermissionToken(t, s, "engineer")
	p.fail = true
	w := secondPermissionHTTP(s, token, http.MethodGet, "/api/v38/orders/"+order.ID+"/evidence/public-report", "", nil)
	if w.Code != 500 || strings.Contains(w.Body.String(), "public-repair-report") {
		t.Fatal("audit save failure released a file")
	}
	p.fail = false
	s.state.Orders[0].AssigneeID = "outsource"
	w = secondPermissionHTTP(s, token, http.MethodGet, "/api/v38/orders/"+order.ID+"/evidence/public-report", "", nil)
	if w.Code != 404 {
		t.Fatal("old assigned engineer kept download access")
	}
}

func TestSecondPassPermissionsAuditPaginationBounds(t *testing.T) {
	s, _ := testService(t)
	token := secondPermissionToken(t, s, "admin")
	for _, endpoint := range []string{"/api/v38/orders", "/api/v38/audit"} {
		w := secondPermissionHTTP(s, token, http.MethodGet, endpoint+"?page=100000&pageSize=200", "", nil)
		if w.Code != 200 {
			t.Fatalf("maximum allowed pagination: %s HTTP=%d", endpoint, w.Code)
		}
		var result struct {
			Items []json.RawMessage `json:"items"`
		}
		if json.Unmarshal(w.Body.Bytes(), &result) != nil || len(result.Items) != 0 {
			t.Fatal("out-of-range page must be safely empty")
		}
		for _, query := range []string{"page=100001", "page=2147483647", "page=9223372036854775807", "page=9223372036854775808", "page=" + strings.Repeat("9", 1000), "page=-1", "page=0", "pageSize=201", "pageSize=9223372036854775808"} {
			w := secondPermissionHTTP(s, token, http.MethodGet, endpoint+"?"+query, "", nil)
			if w.Code != 422 {
				t.Fatalf("unsafe pagination not rejected: %s HTTP=%d", endpoint, w.Code)
			}
		}
	}
	for _, role := range []string{"dispatcher", "finance", "engineer", "warehouse", "qc", "customer", "supplier"} {
		w := secondPermissionHTTP(s, secondPermissionToken(t, s, role), http.MethodGet, "/api/v38/audit?"+url.Values{"page": {"100000"}, "pageSize": {"200"}}.Encode(), "", nil)
		if w.Code != 403 {
			t.Fatalf("non-admin read audit: %s HTTP=%d", role, w.Code)
		}
	}
}

func TestSecondPassPermissionsReproduceHiddenRemarkOverwrite(t *testing.T) {
	s, _ := testService(t)
	order := secondPermissionsFixture(s)
	actor := testActor(s, "qc")
	view := s.view(order, &s.state, actor)
	if view.Remark != "" {
		t.Fatal("fixture must hide internal remark for QC")
	}
	_, err := testActVersion(s, actor, order.ID, "remark", map[string]any{"remark": view.Remark, "customerNote": "public-note-updated-by-qc"}, order.Version, "second-remark-overwrite")
	if err != nil {
		t.Fatalf("diagnostic action rejected: %v", err)
	}
	actual := testOrder(t, s, order.ID).Remark
	if actual != "" {
		t.Fatal("reported behavior changed: original remark is no longer erased")
	}
	t.Log("CONFIRMED: QC reads blank hidden Remark; customerNote edit with that blank value erases stored internal remark (expected preserve/reject; actual committed empty)")
}

func TestSecondPassPermissionsReproduceHiddenObligationResolution(t *testing.T) {
	s, _ := testService(t)
	order := secondPermissionsFixture(s)
	actor := testActor(s, "qc")
	for _, task := range s.view(order, &s.state, actor).Obligations {
		if task.ID == "finance-task" {
			t.Fatal("fixture must hide the finance-owned task")
		}
	}
	_, err := testActVersion(s, actor, order.ID, "resolve_obligation", map[string]any{"obligationId": "finance-task", "note": "second-pass synthetic completion"}, order.Version, "second-hidden-task")
	if err != nil {
		t.Fatalf("diagnostic action rejected: %v", err)
	}
	resolved := false
	for _, task := range testOrder(t, s, order.ID).Obligations {
		if task.ID == "finance-task" {
			resolved = task.Resolved
		}
	}
	if !resolved {
		t.Fatal("reported behavior changed: finance-owned task is no longer resolved")
	}
	t.Log("CONFIRMED: QC cannot read finance-owned obligation but can resolve it when its ID is supplied (expected owner/privileged authorization check; actual resolved)")
}

func TestSecondPassPermissionsReproduceReplayWithoutReadAudit(t *testing.T) {
	s, p := testService(t)
	order := secondPermissionsFixture(s)
	token := secondPermissionToken(t, s, "admin")
	raw := []byte(`{"type":"remark","version":1,"payload":{"remark":"second-admin-note","customerNote":"public-note"}}`)
	path := "/api/v38/orders/" + order.ID + "/actions"
	first := secondPermissionHTTP(s, token, http.MethodPost, path, "second-replay-audit", raw)
	if first.Code != 200 {
		t.Fatalf("initial write failed HTTP=%d", first.Code)
	}
	beforeAudit := len(s.state.Audit)
	p.fail = true
	detail := secondPermissionHTTP(s, token, http.MethodGet, "/api/v38/orders/"+order.ID, "", nil)
	again := secondPermissionHTTP(s, token, http.MethodPost, path, "second-replay-audit", raw)
	if detail.Code != 500 || again.Code != 200 || !strings.Contains(again.Body.String(), "private-finance-cost-sentinel") || len(s.state.Audit) != beforeAudit {
		t.Fatal("reported audit/replay behavior changed")
	}
	t.Log("CONFIRMED: audit persistence failure blocks GET detail with 500, while cached POST replay returns full Order with 200 and no new audit (expected equivalent protected-content release boundary)")
}
