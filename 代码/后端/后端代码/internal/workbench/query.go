package workbench

import (
	"net/url"
	"strconv"
	"strings"
)

type OrderQuery struct {
	Page, PageSize                        int
	Q, Status, Filter, Documents, Payment string
}

type OrderPage struct {
	Items      []Order        `json:"items"`
	Total      int            `json:"total"`
	Page       int            `json:"page"`
	PageSize   int            `json:"pageSize"`
	TotalPages int            `json:"totalPages"`
	Counts     map[string]int `json:"counts"`
}

func parseOrderQuery(values url.Values) (OrderQuery, error) {
	query := OrderQuery{Page: 1, PageSize: 30, Q: strings.ToLower(strings.TrimSpace(values.Get("q"))), Status: values.Get("status"), Filter: values.Get("filter"), Documents: values.Get("documents"), Payment: values.Get("payment")}
	for name, target := range map[string]*int{"page": &query.Page, "pageSize": &query.PageSize} {
		if input := values.Get(name); input != "" {
			number, err := strconv.Atoi(input)
			if err != nil || number < 1 || name == "page" && number > 100000 || name == "pageSize" && number > 200 {
				return query, fail(422, "invalid_page", "页码或每页数量无效，每页最多200条")
			}
			*target = number
		}
	}
	if len(query.Q) > 1000 || !oneOf(query.Documents, "", "required", "sent", "not_required") || !oneOf(query.Payment, "", "outstanding", "pending", "paid") {
		return query, fail(422, "invalid_filter", "筛选条件无效")
	}
	return query, nil
}

func oneOf(value string, values ...string) bool {
	for _, candidate := range values {
		if value == candidate {
			return true
		}
	}
	return false
}

// Derived fields are scalar replacements, so no evidence/event graph copy is needed.
func (s *Service) derivedOrder(order Order) Order {
	s.refresh(&order, &s.state)
	return order
}

func (s *Service) orderSummary(order Order, actor Actor) Order {
	order.Quote.Signature = ""
	order.AcceptanceSignature = ""
	order.AcceptanceRecords = nil
	order.QuoteHistory = []Quote{}
	order.Evidence = []Evidence{}
	order.Events = []Event{}
	order.Outsource = []Outsource{}
	order.Cash = append([]Cash{}, order.Cash...)
	result := redactOrderView(order, actor)
	result.Costs = []Cost{}
	result.Commissions = []Commission{}
	result.IsSummary = true
	return result
}

func (s *Service) queryOrders(actor Actor, query OrderQuery) OrderPage {
	page := OrderPage{Items: []Order{}, Page: query.Page, PageSize: query.PageSize, Counts: map[string]int{"all": 0, "mine": 0, "settling": 0, "pending_completion": 0, "blocked": 0}}
	start := (query.Page - 1) * query.PageSize
	for index := len(s.state.Orders) - 1; index >= 0; index-- {
		raw := s.state.Orders[index]
		if !visible(raw, actor) {
			continue
		}
		order := s.derivedOrder(raw)
		order.Summary.PendingCashCents = visiblePendingCash(order, actor)
		if query.Status == "active" && order.Status == "completed" || query.Status != "" && query.Status != "active" && order.Status != query.Status {
			continue
		}
		haystack := order.Number + " " + order.Customer + " " + order.Project + " " + order.Device + " " + order.Description + " " + order.OwnerID
		if oneOf(actor.Role, "admin", "dispatcher", "finance") {
			haystack += " " + order.Remark
		}
		if query.Q != "" && !strings.Contains(strings.ToLower(haystack), query.Q) {
			continue
		}
		summary := order.Summary
		if query.Documents == "sent" && summary.DocumentStatus != "已发送" || query.Documents == "not_required" && summary.DocumentStatus != "无需，已确认" || query.Documents == "required" && oneOf(summary.DocumentStatus, "已发送", "无需，已确认") {
			continue
		}
		if query.Payment == "outstanding" && summary.RemainingCents == 0 || query.Payment == "pending" && (!internal(actor) || summary.PendingCashCents == 0) || query.Payment == "paid" && (summary.RemainingCents != 0 || summary.OverpaidCents != 0 || summary.PendingCashCents != 0) {
			continue
		}
		// Tab数量包含当前公共筛选的全部授权记录，不受当前Tab或分页截断。
		for filter := range page.Counts {
			if matchesFilter(order, actor, filter) {
				page.Counts[filter]++
			}
		}
		if !matchesFilter(order, actor, query.Filter) {
			continue
		}
		if page.Total >= start && len(page.Items) < query.PageSize {
			page.Items = append(page.Items, s.orderSummary(order, actor))
		}
		page.Total++
	}
	page.TotalPages = (page.Total + query.PageSize - 1) / query.PageSize
	return page
}

func (s *Service) dashboard(actor Actor) map[string]any {
	result := s.bootstrapMetadata(actor)
	page := s.queryOrders(actor, OrderQuery{Page: 1, PageSize: 30})
	result["orders"] = page.Items
	result["orderPage"] = map[string]int{"page": page.Page, "pageSize": page.PageSize, "total": page.Total, "totalPages": page.TotalPages}
	metrics := map[string]int64{"openCount": 0, "settlingCount": 0, "remainingCents": 0, "readyCount": 0, "tasksCount": 0, "blockedCount": 0}
	for _, raw := range s.state.Orders {
		if !visible(raw, actor) {
			continue
		}
		order := s.derivedOrder(raw)
		metrics["remainingCents"] += order.Summary.RemainingCents
		if order.Status != "completed" {
			metrics["openCount"]++
			metrics["tasksCount"]++
			if internal(actor) {
				for _, visit := range order.Visits {
					if (readsFinancialDetails(actor) || actor.Role == "engineer") && visit.StartedAt == "" {
						metrics["tasksCount"]++
					}
				}
				for _, issue := range order.Issues {
					if !issue.Resolved {
						metrics["tasksCount"]++
					}
				}
				for _, task := range order.Obligations {
					if (readsFinancialDetails(actor) || task.OwnerID == actor.ID) && !task.Resolved {
						metrics["tasksCount"]++
					}
				}
			}
		}
		if order.Status == "settling" {
			metrics["settlingCount"]++
		}
		if order.Status == "pending_completion" {
			metrics["readyCount"]++
		}
		for _, issue := range order.Issues {
			if !issue.Resolved {
				metrics["blockedCount"]++
				break
			}
		}
	}
	result["metrics"], result["capacity"] = metrics, s.capacity()
	return result
}

func visiblePendingCash(order Order, actor Actor) int64 {
	if readsFinancialDetails(actor) {
		return order.Summary.PendingCashCents
	}
	var value int64
	if readsOwnExpenses(actor) {
		for _, cash := range order.Cash {
			if !cash.Verified && cash.Collector == actor.ID {
				value += cash.AmountCents
			}
		}
	}
	return value
}
