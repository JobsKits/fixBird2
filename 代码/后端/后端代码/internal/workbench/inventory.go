package workbench

import "time"

type LoanInput struct {
	OrderID    string `json:"orderId"`
	PartID     string `json:"partId"`
	Quantity   int    `json:"quantity"`
	BorrowerID string `json:"borrowerId"`
	DueAt      string `json:"dueAt"`
	Note       string `json:"note"`
}
type loanPayload struct {
	Quantity  int    `json:"quantity"`
	Condition string `json:"condition"`
	Reason    string `json:"reason"`
	OwnerID   string `json:"ownerId"`
	DueAt     string `json:"dueAt"`
}
type PurchaseInput struct {
	Supplier  string `json:"supplier"`
	PartID    string `json:"partId"`
	Quantity  int    `json:"quantity"`
	UnitCents int64  `json:"unitCents"`
	Note      string `json:"note"`
}
type PurchaseReceive struct {
	Version  int    `json:"version"`
	Quantity int    `json:"quantity"`
	Note     string `json:"note"`
}

func (s *Service) createLoan(state *State, actor Actor, input LoanInput) (Loan, error) {
	if err := roles(actor, "admin", "warehouse"); err != nil {
		return Loan{}, err
	}
	if input.Quantity < 1 || input.Quantity > 100000 || !accountExists(state, input.BorrowerID, "engineer") || !textValid(input.Note, 1, 2000) {
		return Loan{}, fail(422, "invalid_loan", "实际借出须有数量、内部借用人和批准／交接依据")
	}
	if _, err := parseDate(input.DueAt); err != nil {
		return Loan{}, err
	}
	var order *Order
	if input.OrderID != "" {
		var err error
		order, err = findOrder(state, input.OrderID, actor)
		if err != nil {
			return Loan{}, err
		}
		if order.Status == "completed" {
			return Loan{}, fail(422, "reopen_required", "已完结工单须先重开才能新增关联借用")
		}
	}
	part, err := findPart(state, input.PartID)
	if err != nil {
		return Loan{}, err
	}
	if input.Quantity > part.Available {
		return Loan{}, fail(422, "insufficient_inventory", "可用库存不足，未执行借出")
	}
	part.Available -= input.Quantity
	loan := Loan{ID: randomID("loan_"), Version: 1, OrderID: input.OrderID, PartID: part.ID, PartName: part.Name, Quantity: input.Quantity, Outstanding: input.Quantity, BorrowerID: input.BorrowerID, DueAt: input.DueAt, Note: input.Note, Transfers: []LoanTransfer{}}
	state.Loans = append(state.Loans, loan)
	if order != nil {
		addEvent(order, actor, "loan", "仓库确认实际借出", input.Note, true, s.now())
		order.Version++
		order.UpdatedAt = nowString(s.now())
		s.refresh(order, state)
	}
	return loan, nil
}

func (s *Service) loanAction(state *State, actor Actor, id string, action Action) (Loan, error) {
	if err := roles(actor, "admin", "warehouse"); err != nil {
		return Loan{}, err
	}
	var loan *Loan
	for i := range state.Loans {
		if state.Loans[i].ID == id {
			loan = &state.Loans[i]
			break
		}
	}
	if loan == nil {
		return Loan{}, fail(404, "not_found", "借用记录不存在")
	}
	if err := versionCheck(loan.Version, action.Version); err != nil {
		return Loan{}, err
	}
	var p loanPayload
	if err := decodeStrict(action.Payload, &p); err != nil {
		return Loan{}, err
	}
	if p.Quantity < 1 || p.Quantity > loan.Outstanding {
		return Loan{}, fail(422, "loan_quantity_exceeded", "归还／处置数量不能超过尚欠")
	}
	part, err := findPart(state, loan.PartID)
	if err != nil {
		return Loan{}, err
	}
	switch action.Type {
	case "return":
		if p.Condition == "good" {
			loan.ReturnedGood += p.Quantity
			part.Available += p.Quantity
		} else if p.Condition == "quarantine" {
			loan.ReturnedQuarantine += p.Quantity
			part.Quarantine += p.Quantity
		} else {
			return Loan{}, fail(422, "invalid_condition", "请按实物成色选择完好或隔离归还")
		}
		loan.Outstanding -= p.Quantity
	case "consume", "dispose":
		if actor.Role != "admin" {
			return Loan{}, fail(403, "approval_required", "转耗用／遗失损坏处置须管理员批准")
		}
		if !textValid(p.Reason, 1, 2000) {
			return Loan{}, fail(422, "reason_required", "耗用／处置须有批准依据，不计销售收入")
		}
		if action.Type == "consume" {
			if loan.OrderID == "" {
				return Loan{}, fail(422, "order_required", "转维修耗用须关联工单及成本依据")
			}
			loan.Consumed += p.Quantity
		} else {
			loan.Disposed += p.Quantity
		}
		loan.Outstanding -= p.Quantity
	case "transfer":
		if actor.Role != "admin" {
			return Loan{}, fail(403, "approval_required", "独立跟踪转出须管理员批准")
		}
		if !textValid(p.Reason, 1, 2000) || !accountExists(state, p.OwnerID, "engineer", "warehouse", "admin") {
			return Loan{}, fail(422, "transfer_basis_required", "转独立跟踪须有批准依据和责任人")
		}
		if _, err = parseDate(p.DueAt); err != nil {
			return Loan{}, err
		}
		transferred := 0
		for _, t := range loan.Transfers {
			transferred += t.Quantity
		}
		if p.Quantity > loan.Outstanding-transferred {
			return Loan{}, fail(422, "transfer_quantity_exceeded", "此数量已转出独立跟踪或超过工单尚欠")
		}
		loan.Transfers = append(loan.Transfers, LoanTransfer{Quantity: p.Quantity, OwnerID: p.OwnerID, DueAt: p.DueAt, Reason: p.Reason, At: nowString(s.now())})
	default:
		return Loan{}, fail(422, "unknown_action", "不支持的借还动作")
	}
	// Cleared quantities reduce independent tracking first, keeping global debt once.
	if action.Type != "transfer" {
		left := p.Quantity
		for i := range loan.Transfers {
			take := min(left, loan.Transfers[i].Quantity)
			loan.Transfers[i].Quantity -= take
			left -= take
			if left == 0 {
				break
			}
		}
	}
	loan.Version++
	if loan.OrderID != "" {
		for i := range state.Orders {
			order := &state.Orders[i]
			if order.ID == loan.OrderID {
				addEvent(order, actor, "loan_"+action.Type, "办理配件借还／批准处置", p.Reason, true, s.now())
				order.Version++
				order.UpdatedAt = nowString(s.now())
				s.refresh(order, state)
				break
			}
		}
	}
	return *loan, nil
}

func (s *Service) createPurchase(state *State, actor Actor, input PurchaseInput) (Purchase, error) {
	if err := roles(actor, "admin", "warehouse", "dispatcher"); err != nil {
		return Purchase{}, err
	}
	if !textValid(input.Supplier, 1, 200) || input.Quantity < 1 || input.Quantity > 100000 || !textValid(input.Note, 1, 2000) {
		return Purchase{}, fail(422, "invalid_purchase", "采购须有供应商、数量和批准依据")
	}
	if err := amount(input.UnitCents, false); err != nil {
		return Purchase{}, err
	}
	if _, err := findPart(state, input.PartID); err != nil {
		return Purchase{}, err
	}
	value := Purchase{ID: randomID("purchase_"), Version: 1, Supplier: input.Supplier, PartID: input.PartID, Quantity: input.Quantity, UnitCents: input.UnitCents, Note: input.Note}
	state.Purchases = append(state.Purchases, value)
	return value, nil
}

func (s *Service) receivePurchase(state *State, actor Actor, id string, input PurchaseReceive) (Purchase, error) {
	if err := roles(actor, "admin", "warehouse"); err != nil {
		return Purchase{}, err
	}
	for i := range state.Purchases {
		purchase := &state.Purchases[i]
		if purchase.ID != id {
			continue
		}
		if err := versionCheck(purchase.Version, input.Version); err != nil {
			return Purchase{}, err
		}
		if input.Quantity < 1 || input.Quantity > purchase.Quantity-purchase.Received || !textValid(input.Note, 1, 2000) {
			return Purchase{}, fail(422, "receive_quantity_exceeded", "按实际分批收货填写数量，不可超收")
		}
		part, err := findPart(state, purchase.PartID)
		if err != nil {
			return Purchase{}, err
		}
		part.Available += input.Quantity
		purchase.Received += input.Quantity
		purchase.Version++
		return *purchase, nil
	}
	return Purchase{}, fail(404, "not_found", "采购单不存在")
}

func (s *Service) autoAccept(state *State, actor Actor) (map[string]any, error) {
	if err := roles(actor, "admin", "dispatcher"); err != nil {
		return nil, err
	}
	accepted := []string{}
	review := []string{}
	for i := range state.Orders {
		order := &state.Orders[i]
		if order.Status != "pending_acceptance" || order.Type == "onsite" || !order.Quote.AutoAccept || !order.Quote.Signed || order.DeliveredAt == "" || order.AcceptanceDueAt == "" {
			continue
		}
		deadline, err := time.Parse(time.RFC3339, order.AcceptanceDueAt)
		if err != nil || deadline.After(s.now()) {
			continue
		}
		if order.RestartReview || noIssues(*order) != nil {
			review = append(review, order.ID)
			continue
		}
		if err = s.acceptance(order, deadline, "system_auto_acceptance", ""); err != nil {
			return nil, err
		}
		addEvent(order, Actor{ID: "system", Name: "系统", Role: "system"}, "auto_accept", "系统自动验收", "规则 v38-cn-calendar-days：可靠完整交付、客户接受规则、期限到达、无异议；业务生效="+nowString(deadline)+"，执行="+nowString(s.now()), false, s.now())
		order.Version++
		order.UpdatedAt = nowString(s.now())
		s.refresh(order, state)
		accepted = append(accepted, order.ID)
	}
	return map[string]any{"accepted": accepted, "reviewRequired": review, "message": "停机期间异议待人工核实的单据不自动验收"}, nil
}
