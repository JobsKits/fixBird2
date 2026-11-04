package workbench

import "strings"

// Operational roles receive customer-facing progress and their own expense facts.
func readsFinancialDetails(actor Actor) bool {
	switch actor.Role {
	case "admin", "dispatcher", "finance":
		return true
	default:
		return false
	}
}

func readsOwnExpenses(actor Actor) bool {
	return actor.Role == "engineer" || actor.Role == "warehouse"
}

func canEditInternalRemark(actor Actor) bool {
	return readsFinancialDetails(actor) || actor.Role == "engineer"
}

func canResolveObligation(task Task, actor Actor) bool {
	return actor.Role == "admin" || actor.Role == "dispatcher" || internal(actor) && task.OwnerID == actor.ID
}

// Apply this after the existing external redaction in Service.view. All list,
// detail, export and mutation responses then share the same field policy.
func filterOrderFields(order *Order, actor Actor) {
	if !readsFinancialDetails(actor) && !(actor.Role == "customer" && actor.ID == order.CustomerID) {
		order.AcceptanceRecords = nil
	}
	evidence := make([]Evidence, 0, len(order.Evidence))
	for _, item := range order.Evidence {
		if canReadEvidence(*order, item, actor) {
			evidence = append(evidence, item)
		}
	}
	order.Evidence = evidence
	if readsFinancialDetails(actor) {
		return
	}

	costs := []Cost{}
	if readsOwnExpenses(actor) {
		for _, cost := range order.Costs {
			if cost.OwnerID == actor.ID {
				costs = append(costs, cost)
			}
		}
	}
	order.Costs = costs
	order.Commissions = []Commission{}

	// Verified receipts still support the public invoice/payment progress. An
	// expense submitter also retains their own pending collection and handover.
	cash := []Cash{}
	var ownPendingCents int64
	for _, item := range order.Cash {
		if readsOwnExpenses(actor) && item.Collector == actor.ID {
			cash = append(cash, item)
			if !item.Verified {
				ownPendingCents += item.AmountCents
			}
			continue
		}
		if item.Verified {
			item.Collector = ""
			item.VerifiedBy = ""
			cash = append(cash, item)
		}
	}
	order.Cash = cash
	order.Summary.PendingCashCents = ownPendingCents

	events := make([]Event, 0, len(order.Events))
	for _, event := range order.Events {
		switch event.Type {
		case "cost":
			if !readsOwnExpenses(actor) || event.ActorID != actor.ID {
				continue
			}
		case "commission", "settle_commission":
			continue
		case "outsource":
			continue
		case "remark", "visit", "start_visit":
			if actor.Role != "engineer" {
				event.Note = ""
			}
		case "obligation", "resolve_obligation":
			if event.ActorID != actor.ID {
				event.Note = ""
			}
		case "cash":
			if !readsOwnExpenses(actor) || event.ActorID != actor.ID {
				continue
			}
		case "approve_cost", "verify_cash", "handover_cash", "invoice", "void_invoice", "adjust_receivable", "documents":
			// Action notes can contain approval or internal accounting grounds.
			event.Note = ""
		}
		events = append(events, event)
	}
	order.Events = events

	if internal(actor) {
		// The current model has no per-field visit/outsource grants. Only the
		// assigned engineer needs visit details; warehouse and QC do not.
		if actor.Role != "engineer" {
			order.Remark = ""
			order.Visits = []Visit{}
		}
		order.Outsource = []Outsource{}
		obligations := []Task{}
		hiddenTasks := map[string]bool{}
		for _, task := range order.Obligations {
			if task.OwnerID == actor.ID {
				obligations = append(obligations, task)
			} else {
				hiddenTasks["待办："+task.Title] = true
			}
		}
		order.Obligations = obligations
		filterFinancialTasks(order, hiddenTasks, ownPendingCents)
	}
}

func filterFinancialTasks(order *Order, hiddenTasks map[string]bool, ownPendingCents int64) {
	oldMissing := strings.Join(order.Summary.Missing, "；")
	ownCostPending := false
	for _, cost := range order.Costs {
		ownCostPending = ownCostPending || !cost.Approved
	}
	missing := []string{}
	for _, item := range order.Summary.Missing {
		if hiddenTasks[item] {
			continue
		}
		switch item {
		case "提成待结算", "现金内部交接未完成":
			continue
		case "成本待审核":
			if !ownCostPending {
				continue
			}
		case "现金待财务核实":
			if ownPendingCents == 0 {
				continue
			}
		}
		missing = append(missing, item)
	}
	order.Summary.Missing = missing
	if oldMissing != "" && strings.Contains(order.Summary.NextTask, oldMissing) {
		next := strings.Join(missing, "；")
		if next == "" {
			next = "公司正在核对结算与内部余项"
		}
		order.Summary.NextTask = strings.Replace(order.Summary.NextTask, oldMissing, next, 1)
	}
}

// Metadata and download authorization use this same decision. Stage is the
// only existing classification for an unpublished attachment; unknown stages
// stay private until an authorized user publishes them or their uploader reads.
func canReadEvidence(order Order, evidence Evidence, actor Actor) bool {
	if evidence.Deleted || !visible(order, actor) {
		return false
	}
	if evidence.Public || evidence.UploaderID == actor.ID || readsFinancialDetails(actor) {
		return true
	}
	if !internal(actor) {
		return false
	}
	for _, id := range order.Documents.Files {
		if id == evidence.ID {
			return false
		}
	}
	for _, invoice := range order.Invoices {
		for _, id := range invoice.Files {
			if id == evidence.ID {
				return false
			}
		}
	}
	switch actor.Role {
	case "engineer":
		switch evidence.Stage {
		case "pending_arrangement", "diagnosis_quotation", "pending_customer_confirmation", "pending_execution", "repairing", "pending_quality_check", "pending_delivery":
			return true
		}
	case "warehouse":
		switch evidence.Stage {
		case "pending_arrangement", "pending_execution", "pending_quality_check", "pending_delivery", "pending_acceptance":
			return true
		}
	case "qc":
		switch evidence.Stage {
		case "diagnosis_quotation", "repairing", "pending_quality_check":
			return true
		}
	}
	return false
}
