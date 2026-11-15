package workbench

import (
	"encoding/json"
	"fmt"
	"reflect"
	"testing"
)

func orderCountsFixture(t *testing.T) *Service {
	t.Helper()
	s, _ := testService(t)
	s.state.Orders = nil
	for i := 0; i < 67; i++ {
		order := Order{
			ID: fmt.Sprintf("count-%d", i), Number: fmt.Sprintf("COUNT-%03d", i), Version: 1,
			Type: "mail", Customer: "合成客户", CustomerID: "customer", CompanyID: "company-a",
			Project: "scope-a", AssigneeID: "engineer", OwnerID: "dispatcher", Status: "repairing",
			Documents: Documents{Requirement: "none"}, InvoiceRequirement: "none",
			ReceivableCents: 100, Remark: "PRIVATE-COUNTS-MARKER",
		}
		if i >= 40 {
			order.CustomerID, order.CompanyID, order.AssigneeID, order.Project = "customer-b", "company-b", "outsource", "scope-b"
		}
		if i%2 == 1 {
			order.OwnerID = "admin"
		}
		switch i % 4 {
		case 0:
			order.Issues = []Task{{ID: "first", Title: "合成异议"}, {ID: "second", Title: "另一个合成异议"}}
		case 1:
			order.Outcome, order.Status, order.Documents.Requirement = "accepted", "settling", "required"
		case 2:
			order.Outcome, order.Status, order.ReceivableCents = "accepted", "pending_completion", 0
		case 3:
			order.Outcome, order.Status, order.ReceivableCents = "accepted", "completed", 0
		}
		s.state.Orders = append(s.state.Orders, order)
	}
	return s
}

func TestOrderTabCountsCoverAllAuthorizedPages(t *testing.T) {
	s := orderCountsFixture(t)
	before, _ := json.Marshal(s.state.Orders)
	cases := []struct {
		role                                string
		all, mine, settling, ready, blocked int
	}{
		{"admin", 67, 33, 17, 17, 17},
		{"dispatcher", 67, 34, 17, 17, 17},
		{"engineer", 40, 40, 10, 10, 10},
		{"customer", 40, 40, 10, 10, 10},
		{"customer-b", 27, 27, 7, 7, 7},
		{"outsource", 27, 27, 7, 7, 7},
		{"qc", 67, 0, 17, 17, 17},
		{"supplier", 0, 0, 0, 0, 0},
	}
	for _, tc := range cases {
		t.Run(tc.role, func(t *testing.T) {
			actor := testActor(s, tc.role)
			wanted := map[string]int{"all": tc.all, "mine": tc.mine, "settling": tc.settling, "pending_completion": tc.ready, "blocked": tc.blocked}
			for _, number := range []int{1, 2, 10000} {
				page := s.queryOrders(actor, OrderQuery{Page: number, PageSize: 1, Filter: "settling"})
				if !reflect.DeepEqual(page.Counts, wanted) || page.Total != tc.settling {
					t.Fatalf("counts truncated or outside role scope: page=%d got=%v total=%d wanted=%v", number, page.Counts, page.Total, wanted)
				}
				if len(page.Items) > 1 || number == 10000 && len(page.Items) != 0 {
					t.Fatal("counts changed pagination")
				}
			}
		})
	}
	after, _ := json.Marshal(s.state.Orders)
	if string(before) != string(after) {
		t.Fatal("counting changed stored orders")
	}
}

func TestOrderTabCountsRespectCommonFiltersAndActiveStage(t *testing.T) {
	s := orderCountsFixture(t)
	actor := testActor(s, "admin")
	cases := []struct {
		name                          string
		query                         OrderQuery
		all, settling, ready, blocked int
	}{
		{"active", OrderQuery{Status: "active"}, 51, 17, 17, 17},
		{"completed", OrderQuery{Status: "completed"}, 16, 0, 0, 0},
		{"public search", OrderQuery{Q: "scope-a"}, 40, 10, 10, 10},
		{"documents required", OrderQuery{Documents: "required"}, 17, 17, 0, 0},
		{"documents not required", OrderQuery{Documents: "not_required"}, 50, 0, 17, 17},
		{"outstanding", OrderQuery{Payment: "outstanding"}, 34, 17, 0, 17},
		{"paid", OrderQuery{Payment: "paid"}, 33, 0, 17, 0},
		{"combined", OrderQuery{Q: "scope-a", Status: "active", Payment: "outstanding"}, 20, 10, 0, 10},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			query := tc.query
			query.Page, query.PageSize, query.Filter = 1, 1, "mine"
			page := s.queryOrders(actor, query)
			if page.Counts["all"] != tc.all || page.Counts["settling"] != tc.settling || page.Counts["pending_completion"] != tc.ready || page.Counts["blocked"] != tc.blocked {
				t.Fatalf("common filters counted incorrectly: got=%v", page.Counts)
			}
			for filter, count := range page.Counts {
				query.Filter = filter
				independent := s.queryOrders(actor, query)
				if independent.Total != count || !reflect.DeepEqual(independent.Counts, page.Counts) {
					t.Fatalf("tab %s count=%d disagrees with its query total=%d", filter, count, independent.Total)
				}
				if query.Status == "active" {
					for _, order := range independent.Items {
						if order.Status == "completed" {
							t.Fatal("active stage included a completed order")
						}
					}
				}
			}
		})
	}
	for _, tc := range []struct{ role, search string }{
		{"customer", "scope-b"}, {"customer-b", "scope-a"}, {"engineer", "private-counts-marker"},
	} {
		page := s.queryOrders(testActor(s, tc.role), OrderQuery{Page: 1, PageSize: 1, Q: tc.search})
		for filter, count := range page.Counts {
			if count != 0 {
				t.Fatalf("%s inferred unauthorized data from %s count %d", tc.role, filter, count)
			}
		}
	}
}

func TestOrderTabCountsAreSerializedByExistingListAPI(t *testing.T) {
	s := orderCountsFixture(t)
	w := fixRequest(t, s, "customer", "GET", "/api/v38/orders?page=2&pageSize=1&filter=settling&status=active", "", "")
	var result OrderPage
	if w.Code != 200 || json.Unmarshal(w.Body.Bytes(), &result) != nil {
		t.Fatalf("list response failed: status=%d body=%s", w.Code, w.Body.String())
	}
	wanted := map[string]int{"all": 30, "mine": 30, "settling": 10, "pending_completion": 10, "blocked": 10}
	if !reflect.DeepEqual(result.Counts, wanted) || result.Total != 10 || result.Page != 2 || len(result.Items) != 1 {
		t.Fatalf("list API lost authorized counts or pagination: %+v", result)
	}
}
