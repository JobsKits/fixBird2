package workbench

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"image/png"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"
)

type Action struct {
	Type    string          `json:"type"`
	Version int             `json:"version"`
	Payload json.RawMessage `json:"payload"`
}
type actionPayload struct {
	OwnerID                 string   `json:"ownerId"`
	CustomerID              string   `json:"customerId"`
	AssigneeID              string   `json:"assigneeId"`
	Note                    string   `json:"note"`
	AmountCents             int64    `json:"amountCents"`
	Description             string   `json:"description"`
	WarrantyMonths          int      `json:"warrantyMonths"`
	PaymentTerms            string   `json:"paymentTerms"`
	PrepayCents             int64    `json:"prepayCents"`
	StartRequiresPrepayment bool     `json:"startRequiresPrepayment"`
	ValidUntil              string   `json:"validUntil"`
	AutoAccept              bool     `json:"autoAccept"`
	Signature               string   `json:"signature"`
	QuoteVersion            int      `json:"quoteVersion"`
	Passed                  bool     `json:"passed"`
	PartID                  string   `json:"partId"`
	Quantity                int      `json:"quantity"`
	Carrier                 string   `json:"carrier"`
	Tracking                string   `json:"tracking"`
	DeliveredAt             string   `json:"deliveredAt"`
	DocumentRequirement     string   `json:"documentRequirement"`
	DocumentReason          string   `json:"documentReason"`
	InvoiceRequirement      string   `json:"invoiceRequirement"`
	InvoiceReason           string   `json:"invoiceReason"`
	InvoiceDueCents         int64    `json:"invoiceDueCents"`
	Prepared                bool     `json:"prepared"`
	Sent                    bool     `json:"sent"`
	Recipient               string   `json:"recipient"`
	Files                   []string `json:"files"`
	Kind                    string   `json:"kind"`
	Purpose                 string   `json:"purpose"`
	Receipt                 string   `json:"receipt"`
	OccurredAt              string   `json:"occurredAt"`
	CashID                  string   `json:"cashId"`
	Number                  string   `json:"number"`
	InvoiceID               string   `json:"invoiceId"`
	Reason                  string   `json:"reason"`
	Remark                  string   `json:"remark"`
	CustomerNote            string   `json:"customerNote"`
	Name                    string   `json:"name"`
	Text                    string   `json:"text"`
	MIME                    string   `json:"mime"`
	Data                    string   `json:"data"`
	EvidenceID              string   `json:"evidenceId"`
	Public                  bool     `json:"public"`
	IssueID                 string   `json:"issueId"`
	DueAt                   string   `json:"dueAt"`
	ReturnRequired          bool     `json:"returnRequired"`
	Title                   string   `json:"title"`
	ObligationID            string   `json:"obligationId"`
	ID                      string   `json:"id"`
	PlannedAt               string   `json:"plannedAt"`
	FeeMemo                 string   `json:"feeMemo"`
	VisitID                 string   `json:"visitId"`
	Provider                string   `json:"provider"`
	Contact                 string   `json:"contact"`
	Destination             string   `json:"destination"`
	Category                string   `json:"category"`
	CostID                  string   `json:"costId"`
	Person                  string   `json:"person"`
	CommissionID            string   `json:"commissionId"`
	Free                    bool     `json:"free"`
}

type CreateOrderInput struct {
	Type            string `json:"type"`
	Customer        string `json:"customer"`
	CustomerID      string `json:"customerId"`
	CompanyID       string `json:"companyId"`
	Project         string `json:"project"`
	Device          string `json:"device"`
	Description     string `json:"description"`
	Remark          string `json:"remark"`
	CustomerNote    string `json:"customerNote"`
	OriginalOrderID string `json:"originalOrderId"`
}

func textValid(value string, min, max int) bool {
	n := utf8.RuneCountInString(strings.TrimSpace(value))
	return utf8.ValidString(value) && n >= min && n <= max
}
func stateIs(order Order, states ...string) error {
	for _, status := range states {
		if order.Status == status {
			return nil
		}
	}
	return fail(422, "invalid_stage", "当前阶段不能执行此动作，请核对实际业务事实")
}
func noIssues(order Order) error {
	for _, issue := range order.Issues {
		if !issue.Resolved {
			return fail(422, "unresolved_issue", "存在未解决异议，请先办理协商结果")
		}
	}
	return nil
}
func executionReady(order Order) error {
	if !order.Quote.Approved || !order.Quote.Signed {
		return fail(422, "quote_not_confirmed", "当前报价尚未公司审核并由客户签署")
	}
	if err := noIssues(order); err != nil {
		return err
	}
	collected := int64(0)
	for _, cash := range order.Cash {
		if cash.Verified {
			if cash.Kind == "receipt" {
				collected += cash.AmountCents
			} else {
				collected -= cash.AmountCents
			}
		}
	}
	required := int64(0)
	if order.Type == "sale" {
		required = order.Quote.PrepayCents
		if order.Quote.PaymentTerms == "cash" {
			required = max(required, order.Quote.AmountCents)
		}
	} else if order.Quote.StartRequiresPrepayment {
		if order.Quote.PrepayCents <= 0 || order.Quote.PrepayCents > order.Quote.AmountCents {
			return fail(422, "invalid_quote", "先款开修约定须有正数预付款且不超过报价")
		}
		required = order.Quote.PrepayCents
	}
	if collected < required {
		return fail(422, "prepayment_required", "约定执行前款项尚未财务核实；现款销售须核实全款")
	}
	return nil
}
func validSignature(value string) error {
	const prefix = "data:image/png;base64,"
	if !strings.HasPrefix(value, prefix) || len(value) > 2*1024*1024 {
		return fail(422, "invalid_signature", "请提交有效的 PNG 手写签名")
	}
	data, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(value, prefix))
	if err != nil {
		return fail(422, "invalid_signature", "签名编码无效")
	}
	cfg, err := png.DecodeConfig(bytes.NewReader(data))
	if err != nil || cfg.Width < 8 || cfg.Height < 8 || cfg.Width > 1600 || cfg.Height > 800 {
		return fail(422, "invalid_signature", "签名图像大小或格式无效")
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		return fail(422, "invalid_signature", "签名图像无效")
	}
	ink := 0
	for y := img.Bounds().Min.Y; y < img.Bounds().Max.Y; y++ {
		for x := img.Bounds().Min.X; x < img.Bounds().Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			if a > 0x4000 && (r < 0xd000 || g < 0xd000 || b < 0xd000) {
				ink++
			}
		}
	}
	if ink < 16 {
		return fail(422, "empty_signature", "签名为空，请实际手写后提交")
	}
	return nil
}

func (s *Service) createOrder(state *State, actor Actor, input CreateOrderInput) (Order, error) {
	if err := roles(actor, "admin", "dispatcher", "customer"); err != nil {
		return Order{}, err
	}
	if input.Type != "mail" && input.Type != "onsite" && input.Type != "sale" {
		return Order{}, fail(422, "invalid_order_type", "请选择寄修、上门或配件销售")
	}
	if !textValid(input.Device, 1, 500) || !textValid(input.Description, 1, 4000) || !textValid(input.Project, 0, 200) || !textValid(input.Remark, 0, state.Settings.RemarkLimit) {
		return Order{}, fail(422, "invalid_order", "设备／需求必填，请检查字段长度")
	}
	if actor.Role == "customer" {
		if input.CompanyID != "" && input.CompanyID != actor.CompanyID {
			return Order{}, fail(403, "cross_company", "不能为其他企业创建工单")
		}
		input.CustomerID = actor.ID
		input.CompanyID = actor.CompanyID
		if input.Customer == "" {
			input.Customer = actor.Name
		}
		input.Remark = ""
	}
	if !accountExists(state, input.CustomerID, "customer") {
		return Order{}, fail(422, "invalid_customer", "请指定有效客户账号")
	}
	for _, account := range state.Accounts {
		if account.Actor.ID == input.CustomerID && account.Actor.CompanyID != input.CompanyID {
			return Order{}, fail(422, "invalid_company", "客户账号与所属企业不匹配")
		}
	}
	if !textValid(input.Customer, 1, 200) {
		return Order{}, fail(422, "invalid_customer", "客户名称必填")
	}
	now := s.now()
	order := newOrder(randomID("wo_"), input, now)
	order.Number = "ZM" + now.In(chinaLocation()).Format("20060102") + "-" + strings.ToUpper(order.ID[len(order.ID)-6:])
	addEvent(&order, actor, "create", "提交维修／销售需求", "合成演示工单已提交", false, now)
	state.Orders = append(state.Orders, order)
	s.refresh(&state.Orders[len(state.Orders)-1], state)
	return s.view(state.Orders[len(state.Orders)-1], state, actor), nil
}

func newOrder(id string, input CreateOrderInput, now time.Time) Order {
	return Order{ID: id, Version: 1, Type: input.Type, Customer: input.Customer, CustomerID: input.CustomerID, CompanyID: input.CompanyID, Project: input.Project, Device: input.Device, Description: input.Description, Status: "pending_intake", CreatedAt: nowString(now), UpdatedAt: nowString(now), Remark: input.Remark, CustomerNote: input.CustomerNote, OriginalOrderID: input.OriginalOrderID, Documents: Documents{Requirement: "unknown", Version: 1, Files: []string{}}, InvoiceRequirement: "unknown", Invoices: []Invoice{}, Cash: []Cash{}, Evidence: []Evidence{}, Events: []Event{}, Visits: []Visit{}, Outsource: []Outsource{}, Costs: []Cost{}, Commissions: []Commission{}, Issues: []Task{}, Obligations: []Task{}, QuoteHistory: []Quote{}, CompletionChecks: []string{}}
}

func (s *Service) act(state *State, actor Actor, id string, action Action) (Order, error) {
	order, err := findOrder(state, id, actor)
	if err != nil {
		return Order{}, err
	}
	if err = versionCheck(order.Version, action.Version); err != nil {
		return Order{}, err
	}
	var p actionPayload
	if len(action.Payload) > 0 {
		if err = decodeStrict(action.Payload, &p); err != nil {
			return Order{}, err
		}
	}
	if !textValid(p.Note, 0, 4000) || !textValid(p.Reason, 0, 2000) {
		return Order{}, fail(422, "text_too_long", "说明过长或编码无效")
	}
	if err = actionPermission(action.Type, actor); err != nil {
		return Order{}, err
	}
	if order.Status == "completed" {
		switch action.Type {
		case "reopen", "rework", "remark", "evidence", "delete_evidence", "handover_contact":
		default:
			return Order{}, fail(422, "reopen_required", "此单已完结，改变账款、票据或余项前须由授权人员有依据地重开")
		}
	}
	now := s.now()
	title := action.Type
	internalEvent := false
	switch action.Type {
	case "intake":
		if err = stateIs(*order, "pending_intake"); err != nil {
			return Order{}, err
		}
		if !accountExists(state, p.OwnerID, "admin", "dispatcher") || !accountExists(state, p.AssigneeID, "engineer", "outsource", "warehouse", "dispatcher") {
			return Order{}, fail(422, "invalid_assignment", "请选择有效负责人和执行人")
		}
		order.OwnerID = p.OwnerID
		order.AssigneeID = p.AssigneeID
		order.Status = "pending_arrangement"
		title = "确认受理并安排负责人"
	case "receive":
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "receive_basis_required", "确认实物收件须登记数量、状态与凭证依据")
		}
		if err = stateIs(*order, "pending_arrangement", "pending_quality_check"); err != nil {
			return Order{}, err
		}
		title = "确认实际收件"
	case "assign":
		if !accountExists(state, p.AssigneeID, "engineer", "outsource", "warehouse", "dispatcher") {
			return Order{}, fail(422, "invalid_assignment", "执行人不存在")
		}
		order.AssigneeID = p.AssigneeID
		title = "派单／改派"
		internalEvent = true
	case "handover_contact":
		if !textValid(p.Reason, 1, 2000) {
			return Order{}, fail(422, "reason_required", "联系人交接须记录授权依据及交接原因")
		}
		if !accountExists(state, p.CustomerID, "customer") {
			return Order{}, fail(422, "invalid_contact", "新经办人须为有效客户账号")
		}
		for _, account := range state.Accounts {
			if account.Actor.ID == p.CustomerID && account.Actor.CompanyID != order.CompanyID {
				return Order{}, fail(403, "cross_company", "新经办人必须属于当前企业")
			}
		}
		p.Note = "原经办人=" + order.CustomerID + "；新经办人=" + p.CustomerID + "；依据=" + p.Reason
		order.CustomerID = p.CustomerID
		title = "确认本单客户联系人交接，撤销原本单访问"
		internalEvent = true
	case "diagnose":
		if err = stateIs(*order, "pending_arrangement"); err != nil {
			return Order{}, err
		}
		order.Status = "diagnosis_quotation"
		title = "确认开始检测"
		if order.Type == "sale" {
			title = "确认开始销售报价"
		}
	case "report":
		if err = stateIs(*order, "diagnosis_quotation"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "report_required", "请填写检测／询价结论")
		}
		title = "提交检测／询价结果"
	case "quote":
		if err = stateIs(*order, "diagnosis_quotation", "pending_customer_confirmation", "pending_execution"); err != nil {
			return Order{}, err
		}
		if err = amount(p.AmountCents, false); err != nil {
			return Order{}, err
		}
		if !textValid(p.Description, 1, 4000) || p.WarrantyMonths <= 0 || p.WarrantyMonths > 60 || (p.PaymentTerms != "cash" && p.PaymentTerms != "credit") || p.PrepayCents < 0 || p.PrepayCents > p.AmountCents {
			return Order{}, fail(422, "invalid_quote", "请完整填写方案、付款约定与质保")
		}
		if order.Type != "sale" && p.StartRequiresPrepayment && p.PrepayCents == 0 {
			return Order{}, fail(422, "invalid_quote", "先款开修约定须填写正数预付款")
		}
		validUntil, e := parseDate(p.ValidUntil)
		if e != nil {
			return Order{}, e
		}
		if !validUntil.After(now) {
			return Order{}, fail(422, "expired_quote", "新报价的接受期限须晚于当前时间")
		}
		if order.Quote.Version > 0 {
			order.QuoteHistory = append(order.QuoteHistory, order.Quote)
		}
		order.Quote = Quote{Version: order.Quote.Version + 1, AmountCents: p.AmountCents, Description: p.Description, WarrantyMonths: p.WarrantyMonths, PaymentTerms: p.PaymentTerms, PrepayCents: p.PrepayCents, StartRequiresPrepayment: p.StartRequiresPrepayment && order.Type != "sale", ValidUntil: nowString(validUntil), AutoAccept: p.AutoAccept && order.Type != "onsite"}
		order.ReceivableCents = p.AmountCents
		order.Status = "diagnosis_quotation"
		title = "生成新版本报价，等待公司审核"
	case "approve_quote":
		if err = stateIs(*order, "diagnosis_quotation"); err != nil {
			return Order{}, err
		}
		if order.Quote.Version == 0 {
			return Order{}, fail(422, "quote_required", "请先制作报价")
		}
		validUntil, _ := parseDate(order.Quote.ValidUntil)
		if !validUntil.After(now) {
			return Order{}, fail(422, "expired_quote", "报价接受期限已过，请重新制作并审核")
		}
		order.Quote.Approved = true
		order.Status = "pending_customer_confirmation"
		title = "公司审核并发送合并报价确认单"
	case "sign_quote":
		if actor.ID != order.CustomerID {
			return Order{}, fail(403, "signer_not_authorized", "当前联系人未获本单签署授权")
		}
		if err = stateIs(*order, "pending_customer_confirmation"); err != nil {
			return Order{}, err
		}
		if !order.Quote.Approved || p.QuoteVersion != order.Quote.Version {
			return Order{}, fail(409, "quote_version_conflict", "报价不是当前已审核版本")
		}
		validUntil, _ := parseDate(order.Quote.ValidUntil)
		if !validUntil.After(now) {
			return Order{}, fail(422, "expired_quote", "报价接受期限已过，请联系公司重新审核报价")
		}
		if err = validSignature(p.Signature); err != nil {
			return Order{}, err
		}
		order.Quote.Signed = true
		order.Quote.Signature = p.Signature
		order.Quote.Signer = actor.Name
		order.Quote.SignedAt = nowString(now)
		order.Status = "pending_execution"
		title = "客户一次签署合并报价与履约条款"
	case "start":
		if order.Type == "sale" {
			return Order{}, fail(422, "sale_branch", "销售单请使用备货出库，不进入维修")
		}
		if err = stateIs(*order, "pending_execution"); err != nil {
			return Order{}, err
		}
		if err = executionReady(*order); err != nil {
			return Order{}, err
		}
		order.Status = "repairing"
		title = "确认实际开始维修"
	case "finish":
		if err = stateIs(*order, "repairing"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "completion_report_required", "请填写维修完工内容")
		}
		order.Status = "pending_quality_check"
		title = "提交维修完工，等待公司质检"
	case "qc":
		if err = stateIs(*order, "pending_quality_check"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "qc_note_required", "请填写测试／质检依据")
		}
		if p.Passed {
			order.Status = "pending_delivery"
			title = "公司测试／质检合格"
		} else {
			order.Status = "pending_execution"
			title = "质检不合格，已确认整改安排"
		}
	case "stock_ready":
		if order.Type != "sale" {
			return Order{}, fail(422, "sale_only", "此动作仅用于配件销售")
		}
		if err = stateIs(*order, "pending_execution"); err != nil {
			return Order{}, err
		}
		if err = executionReady(*order); err != nil {
			return Order{}, err
		}
		part, e := findPart(state, p.PartID)
		if e != nil {
			return Order{}, e
		}
		if p.Quantity < 1 || p.Quantity > part.Available {
			return Order{}, fail(422, "insufficient_inventory", "库存不足或出库数量无效")
		}
		part.Available -= p.Quantity
		order.Status = "pending_delivery"
		title = "销售备货并按已签署范围出库"
	case "dispatch":
		if err = stateIs(*order, "pending_delivery"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Carrier, 1, 200) || !textValid(p.Tracking, 0, 200) {
			return Order{}, fail(422, "delivery_required", "请填写运输／交付方式")
		}
		title = "确认发货／交付出发"
		p.Note = strings.Join([]string{p.Carrier, p.Tracking, p.Note}, " · ")
	case "deliver":
		if err = stateIs(*order, "pending_delivery"); err != nil {
			return Order{}, err
		}
		if err = noIssues(*order); err != nil {
			return Order{}, err
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "delivery_evidence_required", "请填写完整客户签收／现场交接凭证依据")
		}
		delivered := now
		if p.DeliveredAt != "" {
			delivered, err = parseDate(p.DeliveredAt)
			if err != nil {
				return Order{}, err
			}
		}
		if delivered.After(now.Add(time.Minute)) {
			return Order{}, fail(422, "future_delivery", "实收时间不能晚于当前时间")
		}
		order.DeliveredAt = nowString(delivered)
		order.Status = "pending_acceptance"
		order.RestartReview = false
		if order.Quote.AutoAccept && order.Type != "onsite" {
			day := delivered.In(chinaLocation())
			deadline := time.Date(day.Year(), day.Month(), day.Day()+7, 0, 0, 0, 0, chinaLocation())
			order.AcceptanceDueAt = nowString(deadline)
		}
		title = "确认完整客户交付，进入验收"
	case "accept":
		if actor.ID != order.CustomerID {
			return Order{}, fail(403, "signer_not_authorized", "当前联系人未获本单验收授权")
		}
		if err = stateIs(*order, "pending_acceptance"); err != nil {
			return Order{}, err
		}
		if err = validSignature(p.Signature); err != nil {
			return Order{}, err
		}
		record := AcceptanceRecord{ID: randomID("acceptance_"), Passed: p.Passed, Signature: p.Signature, SignerID: actor.ID, SignerName: actor.Name, SignedAt: nowString(now), Note: p.Note, QuoteVersion: order.Quote.Version, OrderVersion: order.Version + 1}
		if !p.Passed {
			if !textValid(p.Note, 1, 4000) {
				return Order{}, fail(422, "issue_required", "验收不通过须记录问题")
			}
			record.IssueID = randomID("issue_")
			order.Issues = append(order.Issues, Task{ID: record.IssueID, Title: p.Note, OwnerID: order.OwnerID, DueAt: nowString(now.Add(48 * time.Hour))})
			title = "客户反馈验收异议，保留原阶段"
		} else {
			if err = noIssues(*order); err != nil {
				return Order{}, err
			}
			if err = s.acceptance(order, now, "customer_signature", p.Signature); err != nil {
				return Order{}, err
			}
			title = "客户签署最终验收确认单"
		}
		order.AcceptanceRecords = append(order.AcceptanceRecords, record)
	case "requirements":
		for _, v := range []string{p.DocumentRequirement, p.InvoiceRequirement} {
			if v != "unknown" && v != "required" && v != "none" {
				return Order{}, fail(422, "invalid_requirement", "需求必须明确为待确认、需要或无需")
			}
		}
		if p.DocumentRequirement != "unknown" && !textValid(p.DocumentReason, 1, 2000) {
			return Order{}, fail(422, "requirement_reason_required", "付款资料需求须记录约定依据")
		}
		if p.InvoiceRequirement != "unknown" && !textValid(p.InvoiceReason, 1, 2000) {
			return Order{}, fail(422, "requirement_reason_required", "开票需求须记录约定依据")
		}
		if err = amount(p.InvoiceDueCents, true); err != nil {
			return Order{}, err
		}
		if p.InvoiceRequirement == "required" && p.InvoiceDueCents == 0 {
			return Order{}, fail(422, "invoice_amount_required", "需票时请填写约定应开含税金额")
		}
		order.Documents.Requirement = p.DocumentRequirement
		order.Documents.Reason = p.DocumentReason
		order.InvoiceRequirement = p.InvoiceRequirement
		order.InvoiceReason = p.InvoiceReason
		order.InvoiceDueCents = p.InvoiceDueCents
		title = "确认本单资料与开票需求"
	case "documents":
		if order.Documents.Requirement != "required" {
			return Order{}, fail(422, "documents_not_required", "请先明确付款资料需要制作")
		}
		if p.Prepared && !checkFiles(*order, p.Files) {
			return Order{}, fail(422, "document_files_required", "已制作资料须关联有效私有文件")
		}
		if p.Sent && (!p.Prepared || !textValid(p.Recipient, 1, 200)) {
			return Order{}, fail(422, "document_recipient_required", "发送前须完成制作并记录接收对象")
		}
		order.Documents.Version++
		order.Documents.Prepared = p.Prepared
		order.Documents.Sent = p.Sent
		order.Documents.Recipient = p.Recipient
		order.Documents.Files = p.Files
		publishFiles(order, p.Files)
		title = "确认付款资料制作／发送"
	case "cash":
		if err = amount(p.AmountCents, false); err != nil {
			return Order{}, err
		}
		if p.Kind != "receipt" && p.Kind != "refund" {
			return Order{}, fail(422, "invalid_cash_kind", "请选择收款或退款")
		}
		if !textValid(p.Purpose, 1, 500) || !textValid(p.Receipt, 1, 500) {
			return Order{}, fail(422, "cash_receipt_required", "请登记用途及现金凭据")
		}
		if _, err = parseDate(p.OccurredAt); err != nil {
			return Order{}, err
		}
		order.Cash = append(order.Cash, Cash{ID: randomID("cash_"), AmountCents: p.AmountCents, Kind: p.Kind, Purpose: p.Purpose, Receipt: p.Receipt, Collector: actor.ID, OccurredAt: p.OccurredAt})
		title = "登记现金，等待财务核实"
		internalEvent = true
	case "verify_cash":
		cash, e := findCash(order, p.CashID)
		if e != nil {
			return Order{}, e
		}
		if cash.Verified {
			return Order{}, fail(422, "already_verified", "此笔现金已核实")
		}
		if cash.Kind == "refund" {
			s.refresh(order, state)
			if cash.AmountCents > order.Summary.CollectedCents {
				return Order{}, fail(422, "refund_exceeds_receipts", "核实退款不能超过已核实净收款")
			}
		}
		cash.Verified = true
		cash.VerifiedBy = actor.ID
		title = "财务核实现金收款／退款"
	case "handover_cash":
		cash, e := findCash(order, p.CashID)
		if e != nil {
			return Order{}, e
		}
		if !cash.Verified {
			return Order{}, fail(422, "cash_not_verified", "请先核实现金")
		}
		cash.HandedOver = true
		title = "确认本单现金内部交接"
		internalEvent = true
	case "invoice":
		if order.InvoiceRequirement != "required" {
			return Order{}, fail(422, "invoice_not_required", "请先明确本单开票要求")
		}
		if err = amount(p.AmountCents, false); err != nil {
			return Order{}, err
		}
		if !textValid(p.Number, 1, 200) || !invoiceFiles(*order, p.Files) {
			return Order{}, fail(422, "invoice_files_required", "真实票号和有效票据文件均须填写")
		}
		for _, v := range order.Invoices {
			if v.Number == p.Number && !v.Voided {
				return Order{}, fail(422, "invoice_duplicate", "此票号已有有效记录")
			}
		}
		order.Invoices = append(order.Invoices, Invoice{ID: randomID("inv_"), Number: p.Number, AmountCents: p.AmountCents, Files: p.Files})
		publishFiles(order, p.Files)
		title = "登记实际电子发票"
	case "void_invoice":
		if !textValid(p.Reason, 1, 2000) {
			return Order{}, fail(422, "reason_required", "红冲／作废须记录依据")
		}
		found := false
		for i := range order.Invoices {
			if order.Invoices[i].ID == p.InvoiceID && !order.Invoices[i].Voided {
				order.Invoices[i].Voided = true
				order.Invoices[i].VoidReason = p.Reason
				found = true
				break
			}
		}
		if !found {
			return Order{}, fail(422, "invoice_not_found", "有效发票不存在")
		}
		title = "登记发票红冲／作废"
		p.Note = p.Reason
	case "adjust_receivable":
		if err = amount(p.AmountCents, true); err != nil {
			return Order{}, err
		}
		if !textValid(p.Reason, 1, 2000) {
			return Order{}, fail(422, "reason_required", "应收调整须有批准依据")
		}
		order.ReceivableCents = p.AmountCents
		title = "依据约定调整有效应收"
		p.Note = p.Reason
	case "remark":
		var patch struct {
			Remark       *string `json:"remark"`
			CustomerNote *string `json:"customerNote"`
		}
		if err = json.Unmarshal(action.Payload, &patch); err != nil {
			return Order{}, fail(422, "invalid_payload", "备注字段格式错误")
		}
		remark, customerNote := order.Remark, order.CustomerNote
		if patch.Remark != nil {
			if canEditInternalRemark(actor) {
				if !textValid(*patch.Remark, 0, state.Settings.RemarkLimit) {
					return Order{}, fail(422, "remark_too_long", "备注超过允许长度")
				}
				remark = *patch.Remark
			} else if *patch.Remark != "" {
				return Order{}, fail(403, "internal_remark_forbidden", "当前角色不能修改内部备注")
			}
			// Older forms send the redacted empty value; keep the hidden record.
		}
		if patch.CustomerNote != nil {
			if !textValid(*patch.CustomerNote, 0, state.Settings.RemarkLimit) {
				return Order{}, fail(422, "remark_too_long", "备注超过允许长度")
			}
			customerNote = *patch.CustomerNote
		}
		p.Note = "内部备注旧版：" + order.Remark + "；新版：" + remark + "；客户说明旧版：" + order.CustomerNote + "；新版：" + customerNote
		order.Remark = remark
		order.CustomerNote = customerNote
		title = "更正工单备注与客户说明"
		internalEvent = true
	case "evidence":
		if !textValid(p.Name, 1, 200) || !textValid(p.Text, 0, 12000) {
			return Order{}, fail(422, "invalid_evidence", "文件名必填，文本长度须在范围内")
		}
		if len(order.Evidence) >= 100 {
			return Order{}, fail(422, "evidence_limit", "演示单据最多100份附件")
		}
		if p.Kind != "text" && p.Kind != "image" && p.Kind != "video" && p.Kind != "audio" && p.Kind != "document" {
			return Order{}, fail(422, "invalid_evidence_kind", "不支持的证据类型")
		}
		data, e := decodeBase64(p.Data)
		if e != nil {
			return Order{}, e
		}
		if len(data) > 8*1024*1024 {
			return Order{}, fail(413, "file_too_large", "单附件最多8 MiB")
		}
		if p.Kind == "text" {
			if !textValid(p.Text, 1, 12000) {
				return Order{}, fail(422, "text_required", "请填写文字证据")
			}
		} else {
			if len(data) == 0 {
				return Order{}, fail(422, "file_required", "请选择文件原件")
			}
			if err = validateMIME(p.Kind, p.MIME, data); err != nil {
				return Order{}, err
			}
		}
		sum := sha256.Sum256(data)
		public := p.Public && internal(actor)
		if actor.Role == "customer" {
			public = true
		}
		order.Evidence = append(order.Evidence, Evidence{ID: randomID("file_"), Name: p.Name, Kind: p.Kind, Text: p.Text, MIME: p.MIME, Data: p.Data, UploaderID: actor.ID, CreatedAt: nowString(now), Stage: order.Status, Public: public, SHA256: hex.EncodeToString(sum[:])})
		title = "添加业务证据"
		internalEvent = !public
	case "delete_evidence":
		if !textValid(p.Reason, 1, 2000) {
			return Order{}, fail(422, "reason_required", "删除证据须记录原因")
		}
		found := false
		for i := range order.Evidence {
			e := &order.Evidence[i]
			if e.ID == p.EvidenceID && !e.Deleted {
				if e.UploaderID != actor.ID && actor.Role != "admin" {
					return Order{}, fail(403, "forbidden", "只能删除本人上传证据；管理员可删除任意证据")
				}
				e.Deleted = true
				e.Data = ""
				e.Text = ""
				e.DeleteReason = p.Reason
				found = true
				break
			}
		}
		if !found {
			return Order{}, fail(404, "not_found", "证据不存在或已删除")
		}
		title = "删除证据并保留失效记录"
		p.Note = p.Reason
	case "issue":
		if !textValid(p.Note, 1, 2000) {
			return Order{}, fail(422, "issue_required", "请填写异议内容")
		}
		owner := p.OwnerID
		if owner == "" {
			owner = order.OwnerID
		}
		if !accountExists(state, owner, "admin", "dispatcher", "finance", "engineer", "warehouse", "qc") {
			return Order{}, fail(422, "issue_owner_required", "异议须有有效责任人")
		}
		if _, err = parseDate(p.DueAt); err != nil {
			return Order{}, err
		}
		order.Issues = append(order.Issues, Task{ID: randomID("issue_"), Title: p.Note, OwnerID: owner, DueAt: p.DueAt})
		title = "登记异议，保留主阶段"
	case "resolve_issue":
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "resolution_required", "请记录真实协商结果")
		}
		if err = resolveTask(order.Issues, p.IssueID, p.Note); err != nil {
			return Order{}, err
		}
		title = "处理单项异议，继续检查其他阻塞"
	case "review_acceptance":
		if err = stateIs(*order, "pending_acceptance"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "review_basis_required", "须登记停机期间线下异议核实及客户确认依据")
		}
		if err = noIssues(*order); err != nil {
			return Order{}, err
		}
		order.RestartReview = false
		title = "核实停机期间线下异议，恢复验收扫描"
	case "failure":
		if order.Outcome != "" {
			return Order{}, fail(422, "outcome_exists", "履约结果已明确，不允许覆盖既有验收或停止记录")
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "failure_basis_required", "停止履约须记录判定、批准和客户沟通依据")
		}
		if err = amount(p.AmountCents, true); err != nil {
			return Order{}, err
		}
		switch p.Reason {
		case "customer_refused", "company_refused", "unrepairable":
			order.Outcome = "failed"
		case "cancelled":
			order.Outcome = "cancelled"
		case "negotiated":
			order.Outcome = "negotiated"
		default:
			return Order{}, fail(422, "invalid_failure_reason", "请选择有效失败／停止类型")
		}
		order.FailureReason = p.Reason
		order.ReceivableCents = p.AmountCents
		order.Status = "settling"
		if p.ReturnRequired {
			order.Obligations = append(order.Obligations, Task{ID: randomID("task_"), Title: "核实设备退件与客户实收", OwnerID: "warehouse", DueAt: nowString(now.Add(48 * time.Hour))})
		}
		title = "批准停止履约，继续结算余项"
	case "obligation":
		if !textValid(p.Title, 1, 500) || !accountExists(state, p.OwnerID) {
			return Order{}, fail(422, "task_required", "必办事项须有标题和责任人")
		}
		if _, err = parseDate(p.DueAt); err != nil {
			return Order{}, err
		}
		order.Obligations = append(order.Obligations, Task{ID: randomID("task_"), Title: p.Title, OwnerID: p.OwnerID, DueAt: p.DueAt})
		title = "添加本单必办余项"
		internalEvent = true
	case "resolve_obligation":
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "resolution_required", "请填写本事项办妥依据")
		}
		var task *Task
		for i := range order.Obligations {
			if order.Obligations[i].ID == p.ObligationID && !order.Obligations[i].Resolved {
				task = &order.Obligations[i]
				break
			}
		}
		if task == nil {
			return Order{}, fail(422, "task_not_found", "未办事项不存在")
		}
		if !canResolveObligation(*task, actor) {
			return Order{}, fail(403, "obligation_forbidden", "仅事项责任人或公司负责人可以确认办妥")
		}
		if err = resolveTask(order.Obligations, p.ObligationID, p.Note); err != nil {
			return Order{}, err
		}
		title = "确认单项余项办妥"
		internalEvent = true
	case "visit":
		if order.Type != "onsite" {
			return Order{}, fail(422, "onsite_only", "内部上门行程仅用于上门单")
		}
		if _, err = parseDate(p.PlannedAt); err != nil {
			return Order{}, err
		}
		if !textValid(p.FeeMemo, 0, 2000) {
			return Order{}, fail(422, "memo_too_long", "费用备忘过长")
		}
		found := false
		if p.ID != "" {
			for i := range order.Visits {
				if order.Visits[i].ID == p.ID {
					if order.Visits[i].StartedAt != "" && (actor.Role != "admin" || !textValid(p.Reason, 1, 2000)) {
						return Order{}, fail(403, "visit_locked", "已经开始的行程只允许管理员有原因地更正")
					}
					order.Visits[i].PlannedAt = p.PlannedAt
					order.Visits[i].FeeMemo = p.FeeMemo
					order.Visits[i].Note = p.Note
					found = true
					break
				}
			}
			if !found {
				return Order{}, fail(404, "not_found", "行程不存在")
			}
		} else {
			order.Visits = append(order.Visits, Visit{ID: randomID("visit_"), PlannedAt: p.PlannedAt, FeeMemo: p.FeeMemo, Note: p.Note})
		}
		title = "安排／更正内部上门行程"
		internalEvent = true
	case "start_visit":
		found := false
		for i := range order.Visits {
			if order.Visits[i].ID == p.VisitID && order.Visits[i].StartedAt == "" {
				order.Visits[i].StartedAt = nowString(now)
				found = true
				break
			}
		}
		if !found {
			return Order{}, fail(422, "visit_not_found", "待开始行程不存在")
		}
		title = "登记实际上门出发"
		internalEvent = true
	case "outsource":
		if !textValid(p.Provider, 1, 200) || !textValid(p.Destination, 0, 500) {
			return Order{}, fail(422, "provider_required", "请填写一手责任机构或后续已知流向")
		}
		order.Outsource = append(order.Outsource, Outsource{ID: randomID("out_"), Provider: p.Provider, Contact: p.Contact, Destination: p.Destination, Note: p.Note})
		title = "登记一手外包或后续可选流向"
		internalEvent = true
	case "cost":
		if err = amount(p.AmountCents, false); err != nil {
			return Order{}, err
		}
		if !textValid(p.Category, 1, 100) || !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "cost_basis_required", "成本须有分类和凭据依据")
		}
		order.Costs = append(order.Costs, Cost{ID: randomID("cost_"), Category: p.Category, AmountCents: p.AmountCents, Note: p.Note, OwnerID: actor.ID})
		title = "登记成本，等待审核"
		internalEvent = true
	case "approve_cost":
		found := false
		for i := range order.Costs {
			if order.Costs[i].ID == p.CostID {
				order.Costs[i].Approved = true
				found = true
				break
			}
		}
		if !found {
			return Order{}, fail(422, "cost_not_found", "成本记录不存在")
		}
		title = "审核本单成本"
		internalEvent = true
	case "commission":
		if err = amount(p.AmountCents, false); err != nil {
			return Order{}, err
		}
		if !textValid(p.Person, 1, 200) || !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "commission_basis_required", "提成须有人员和约定依据")
		}
		order.Commissions = append(order.Commissions, Commission{ID: randomID("com_"), Person: p.Person, AmountCents: p.AmountCents, Note: p.Note})
		title = "登记本单提成"
		internalEvent = true
	case "settle_commission":
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "settlement_basis_required", "请填写结算凭据／批准依据")
		}
		found := false
		for i := range order.Commissions {
			if order.Commissions[i].ID == p.CommissionID {
				order.Commissions[i].Settled = true
				found = true
				break
			}
		}
		if !found {
			return Order{}, fail(422, "commission_not_found", "提成记录不存在")
		}
		title = "确认提成结算"
		internalEvent = true
	case "complete":
		s.refresh(order, state)
		if order.Status != "pending_completion" || len(order.Summary.Missing) > 0 {
			return Order{}, fail(422, "completion_blocked", "本单完结条件未齐："+strings.Join(order.Summary.Missing, "；"))
		}
		order.Status = "completed"
		order.CompletionAt = nowString(now)
		order.CompletionBy = actor.ID
		order.CompletionVersion = order.Version + 1
		order.CompletionChecks = []string{"履约结果明确", "资料要求及发送满足", "票据金额及文件满足", "已核实客户账款一致", "内部余项与借还清理"}
		title = "负责人核对并确认整单完结"
	case "reopen":
		if err = stateIs(*order, "completed"); err != nil {
			return Order{}, err
		}
		if !textValid(p.Reason, 1, 2000) {
			return Order{}, fail(422, "reason_required", "重开须记录更正依据")
		}
		order.Status = "settling"
		order.Obligations = append(order.Obligations, Task{ID: randomID("task_"), Title: "重开复核：" + p.Reason, OwnerID: actor.ID, DueAt: nowString(now.Add(48 * time.Hour))})
		title = "批准重开结算，保留原验收与完结历史"
		p.Note = p.Reason
	case "rework":
		if order.AcceptedAt == "" {
			return Order{}, fail(422, "acceptance_required", "有效验收后的售后使用关联返修子单")
		}
		if !textValid(p.Note, 1, 4000) {
			return Order{}, fail(422, "rework_basis_required", "请填写返修问题与免费／收费判断依据")
		}
		input := CreateOrderInput{Type: order.Type, Customer: order.Customer, CustomerID: order.CustomerID, CompanyID: order.CompanyID, Project: order.Project, Device: order.Device, Description: p.Note, OriginalOrderID: order.ID}
		child := newOrder(randomID("wo_"), input, now)
		child.Number = order.Number + "-R" + strings.ToUpper(child.ID[len(child.ID)-4:])
		child.Remark = "返修免费判断："
		if p.Free {
			child.Remark += "免费"
		} else {
			child.Remark += "收费，另行报价"
		}
		addEvent(&child, actor, "rework", "创建关联返修子单", p.Note, false, now)
		state.Orders = append(state.Orders, child)
		return s.view(child, state, actor), nil
	default:
		return Order{}, fail(422, "unknown_action", "不支持的业务动作")
	}
	addEvent(order, actor, action.Type, title, p.Note, internalEvent, now)
	order.Version++
	order.UpdatedAt = nowString(now)
	s.refresh(order, state)
	return s.view(*order, state, actor), nil
}

func chinaLocation() *time.Location { return time.FixedZone("Asia/Shanghai", 8*60*60) }
func (s *Service) acceptance(order *Order, effective time.Time, mode, signature string) error {
	end, err := warrantyEnd(effective, order.Quote.WarrantyMonths)
	if err != nil {
		return err
	}
	order.Outcome = "accepted"
	order.AcceptedAt = nowString(effective)
	order.AcceptanceMode = mode
	order.AcceptanceSignature = signature
	order.Status = "settling"
	order.RestartReview = false
	order.Warranty = Warranty{StartsAt: nowString(effective), EndsAt: nowString(end)}
	return nil
}
func findCash(order *Order, id string) (*Cash, error) {
	for i := range order.Cash {
		if order.Cash[i].ID == id {
			return &order.Cash[i], nil
		}
	}
	return nil, fail(422, "cash_not_found", "现金记录不存在")
}
func resolveTask(tasks []Task, id, note string) error {
	for i := range tasks {
		if tasks[i].ID == id && !tasks[i].Resolved {
			tasks[i].Resolved = true
			tasks[i].Resolution = note
			return nil
		}
	}
	return fail(422, "task_not_found", "未办事项不存在")
}
func publishFiles(order *Order, ids []string) {
	for i := range order.Evidence {
		for _, id := range ids {
			if order.Evidence[i].ID == id {
				order.Evidence[i].Public = true
			}
		}
	}
}
func validateMIME(kind, mime string, data []byte) error {
	detected := http.DetectContentType(data)
	valid := false
	switch kind {
	case "image":
		valid = (mime == "image/png" || mime == "image/jpeg" || mime == "image/gif") && detected == mime
	case "document":
		valid = (mime == "application/pdf" && detected == "application/pdf") || (strings.HasPrefix(mime, "text/plain") && strings.HasPrefix(detected, "text/plain"))
	case "audio":
		valid = (mime == "audio/mpeg" && bytes.HasPrefix(data, []byte("ID3"))) || (mime == "audio/wav" && bytes.HasPrefix(data, []byte("RIFF"))) || (mime == "audio/ogg" && bytes.HasPrefix(data, []byte("OggS")))
	case "video":
		valid = mime == "video/mp4" && len(data) > 12 && string(data[4:8]) == "ftyp"
	}
	if !valid {
		return fail(422, "unsupported_file", "文件内容与类型不匹配；支持PNG/JPG/GIF/PDF/TXT/MP3/WAV/OGG/MP4")
	}
	return nil
}
func actionPermission(action string, actor Actor) error {
	switch action {
	case "sign_quote", "accept":
		return roles(actor, "customer")
	case "intake", "assign", "approve_quote", "failure", "complete", "reopen", "rework", "requirements", "outsource", "obligation", "resolve_issue", "review_acceptance", "handover_contact":
		return roles(actor, "admin", "dispatcher")
	case "quote", "diagnose", "report":
		return roles(actor, "admin", "dispatcher", "engineer", "outsource")
	case "start", "finish", "start_visit":
		return roles(actor, "admin", "engineer", "outsource")
	case "receive", "stock_ready", "dispatch":
		return roles(actor, "admin", "warehouse")
	case "qc":
		return roles(actor, "admin", "qc")
	case "deliver":
		return roles(actor, "admin", "warehouse", "engineer", "dispatcher")
	case "verify_cash", "handover_cash", "invoice", "void_invoice", "adjust_receivable", "approve_cost", "commission", "settle_commission":
		return roles(actor, "admin", "finance")
	case "documents":
		return roles(actor, "admin", "dispatcher", "finance")
	case "cash", "cost":
		return roles(actor, "admin", "dispatcher", "finance", "engineer", "warehouse")
	case "visit":
		return roles(actor, "admin", "dispatcher", "engineer")
	case "remark", "resolve_obligation":
		return roles(actor, "admin", "dispatcher", "engineer", "warehouse", "qc", "finance")
	case "issue", "evidence", "delete_evidence":
		return roles(actor, "admin", "dispatcher", "engineer", "warehouse", "qc", "finance", "customer", "outsource")
	default:
		return fail(422, "unknown_action", "不支持的业务动作")
	}
}
func allowedActions(order Order, actor Actor) []string {
	result := []string{}
	all := []string{"intake", "receive", "assign", "diagnose", "report", "quote", "approve_quote", "sign_quote", "start", "finish", "qc", "stock_ready", "dispatch", "deliver", "accept", "requirements", "documents", "cash", "verify_cash", "handover_cash", "invoice", "void_invoice", "adjust_receivable", "remark", "evidence", "delete_evidence", "issue", "resolve_issue", "failure", "obligation", "resolve_obligation", "visit", "start_visit", "outsource", "cost", "approve_cost", "commission", "settle_commission", "complete", "reopen", "rework", "review_acceptance", "handover_contact"}
	stages := map[string][]string{"intake": {"pending_intake"}, "receive": {"pending_arrangement", "pending_quality_check"}, "diagnose": {"pending_arrangement"}, "report": {"diagnosis_quotation"}, "quote": {"diagnosis_quotation", "pending_customer_confirmation", "pending_execution"}, "approve_quote": {"diagnosis_quotation"}, "sign_quote": {"pending_customer_confirmation"}, "start": {"pending_execution"}, "finish": {"repairing"}, "qc": {"pending_quality_check"}, "stock_ready": {"pending_execution"}, "dispatch": {"pending_delivery"}, "deliver": {"pending_delivery"}, "accept": {"pending_acceptance"}, "complete": {"pending_completion"}, "reopen": {"completed"}}
	for _, action := range all {
		if actionPermission(action, actor) != nil {
			continue
		}
		if order.Status == "completed" && action != "reopen" && action != "rework" && action != "remark" && action != "evidence" && action != "delete_evidence" && action != "handover_contact" {
			continue
		}
		if allowed, ok := stages[action]; ok && stateIs(order, allowed...) != nil {
			continue
		}
		if action == "start" && order.Type == "sale" || action == "stock_ready" && order.Type != "sale" || (action == "visit" || action == "start_visit") && order.Type != "onsite" || action == "rework" && order.AcceptedAt == "" || action == "failure" && order.Outcome != "" {
			continue
		}
		if action == "review_acceptance" && (order.Status != "pending_acceptance" || !order.RestartReview) {
			continue
		}
		if action == "resolve_obligation" {
			resolvable := false
			for _, task := range order.Obligations {
				if !task.Resolved && canResolveObligation(task, actor) {
					resolvable = true
					break
				}
			}
			if !resolvable {
				continue
			}
		}
		result = append(result, action)
	}
	return result
}
