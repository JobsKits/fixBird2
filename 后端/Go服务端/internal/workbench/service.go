package workbench

import (
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"
)

const maxCents int64 = 100_000_000

type businessError struct {
	Status        int
	Code, Message string
}

func (e *businessError) Error() string            { return e.Message }
func fail(status int, code, message string) error { return &businessError{status, code, message} }

type session struct {
	Actor     Actor
	ExpiresAt time.Time
}
type Service struct {
	mu          sync.Mutex
	state       State
	persistence Persistence
	sessions    map[string]session
	now         func() time.Time
	attempts    map[string]loginAttempt
}
type loginAttempt struct {
	Count int
	Until time.Time
}

func New(p Persistence) (*Service, error) {
	if p == nil {
		return nil, fmt.Errorf("persistence is required")
	}
	s := &Service{persistence: p, sessions: map[string]session{}, now: time.Now, attempts: map[string]loginAttempt{}}
	data, err := p.Load()
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		s.state, err = seedState()
		if err != nil {
			return nil, err
		}
		data, err = json.Marshal(s.state)
		if err != nil {
			return nil, err
		}
		if err = p.Save(data); err != nil {
			return nil, err
		}
	} else {
		if err = json.Unmarshal(data, &s.state); err != nil {
			return nil, fmt.Errorf("invalid workbench snapshot: %w", err)
		}
		if s.state.Schema != 38 {
			return nil, fmt.Errorf("unsupported workbench schema %d", s.state.Schema)
		}
		// A restarted process cannot assume that no offline objection was raised.
		for i := range s.state.Orders {
			if s.state.Orders[i].Status == "pending_acceptance" {
				s.state.Orders[i].RestartReview = true
			}
		}
	}
	if s.state.Requests == nil {
		s.state.Requests = map[string]CachedRequest{}
	}
	if s.state.Audit == nil {
		s.state.Audit = []AuditEvent{}
	}
	normalizeLegacyAudit(&s.state)
	compactRequests(&s.state)
	if err = validateState(s.state); err != nil {
		return nil, err
	}
	return s, nil
}

func passwordHash(password, salt string) (string, error) {
	value, err := pbkdf2.Key(sha256.New, password, []byte(salt), 120_000, 32)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(value), nil
}

func randomID(prefix string) string {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		panic("system randomness unavailable")
	}
	return prefix + hex.EncodeToString(value)
}

func (s *Service) login(username, password, remote string) (string, Actor, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	username = strings.ToLower(strings.TrimSpace(username))
	key := remote + ":" + username
	if len(s.attempts) > 4096 {
		for k, v := range s.attempts {
			if !v.Until.After(now) {
				delete(s.attempts, k)
			}
		}
	}
	attempt := s.attempts[key]
	if !attempt.Until.After(now) {
		attempt = loginAttempt{Until: now.Add(time.Minute)}
	}
	attempt.Count++
	s.attempts[key] = attempt
	if attempt.Count > 12 {
		return "", Actor{}, fail(429, "login_rate_limited", "登录尝试过多，请一分钟后重试")
	}
	if len(username) > 64 || len(password) > 256 {
		return "", Actor{}, fail(401, "invalid_credentials", "账号或密码错误")
	}
	var account Account
	found := false
	for _, a := range s.state.Accounts {
		if a.Actor.Username == username {
			account = a
			found = true
			break
		}
	}
	if !found {
		account.Salt = "unknown-demo-account"
	}
	hash, err := passwordHash(password, account.Salt)
	if err != nil {
		return "", Actor{}, err
	}
	if !found || !activeActor(account.Actor) || subtle.ConstantTimeCompare([]byte(hash), []byte(account.Hash)) != 1 {
		return "", Actor{}, fail(401, "invalid_credentials", "账号或密码错误")
	}
	delete(s.attempts, key)
	token := randomID("") + randomID("")
	s.sessions[token] = session{Actor: account.Actor, ExpiresAt: now.Add(12 * time.Hour)}
	return token, account.Actor, nil
}

func (s *Service) authenticate(token string) (Actor, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	value, ok := s.sessions[token]
	if !ok || !value.ExpiresAt.After(s.now()) {
		delete(s.sessions, token)
		return Actor{}, fail(401, "unauthenticated", "请先登录演示工作台")
	}
	for _, a := range s.state.Accounts {
		if a.Actor.ID == value.Actor.ID {
			if !activeActor(a.Actor) || a.Actor.AuthVersion != value.Actor.AuthVersion {
				delete(s.sessions, token)
				return Actor{}, fail(401, "unauthenticated", "账号已停用，请联系负责人交接")
			}
			return a.Actor, nil
		}
	}
	delete(s.sessions, token)
	return Actor{}, fail(401, "unauthenticated", "账号授权已撤销")
}

func (s *Service) transact(actor Actor, path, key string, raw []byte, status int, fn func(*State) (any, error)) (json.RawMessage, int, error) {
	if key == "" || len(key) > 128 {
		return nil, 0, fail(422, "idempotency_key_required", "每个写请求需要 1—128 字符的 Idempotency-Key")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	currentActor, found := Actor{}, false
	for _, a := range s.state.Accounts {
		if a.Actor.ID == actor.ID {
			currentActor = a.Actor
			found = true
			break
		}
	}
	if !found || !activeActor(currentActor) || currentActor.AuthVersion != actor.AuthVersion {
		return nil, 0, fail(401, "unauthenticated", "账号授权已变化，请重新登录")
	}
	actor = currentActor
	requestKey := actor.ID + ":" + path + ":" + key
	sum := sha256.Sum256(raw)
	hash := hex.EncodeToString(sum[:])
	if old, ok := s.state.Requests[requestKey]; ok {
		if old.Hash != hash {
			return nil, 0, fail(409, "idempotency_conflict", "此请求键已用于不同内容，请核对原请求结果")
		}
		return s.replayRequest(actor, path, old)
	}
	data, err := json.Marshal(s.state)
	if err != nil {
		return nil, 0, err
	}
	var next State
	if err = json.Unmarshal(data, &next); err != nil {
		return nil, 0, err
	}
	value, err := fn(&next)
	if err != nil {
		return nil, 0, err
	}
	if err = validateState(next); err != nil {
		return nil, 0, err
	}
	response, err := json.Marshal(value)
	if err != nil {
		return nil, 0, err
	}
	next.Requests[requestKey] = CachedRequest{Hash: hash, Status: status, Body: compactResponse(response), At: s.now().UTC()}
	data, err = json.Marshal(next)
	if err != nil {
		return nil, 0, err
	}
	if err = s.persistence.Save(data); err != nil {
		return nil, 0, fmt.Errorf("save workbench snapshot: %w", err)
	}
	s.state = next
	return response, status, nil
}

func validateState(state State) error {
	if err := validateAccounts(state.Accounts); err != nil {
		return err
	}
	for _, part := range state.Parts {
		if part.Available < 0 || part.Quarantine < 0 {
			return fmt.Errorf("negative inventory: %s", part.ID)
		}
	}
	for _, loan := range state.Loans {
		if loan.Quantity < 1 || loan.Outstanding < 0 || loan.ReturnedGood < 0 || loan.ReturnedQuarantine < 0 || loan.Consumed < 0 || loan.Disposed < 0 || loan.Quantity != loan.ReturnedGood+loan.ReturnedQuarantine+loan.Consumed+loan.Disposed+loan.Outstanding {
			return fmt.Errorf("loan conservation violated: %s", loan.ID)
		}
	}
	for _, order := range state.Orders {
		if order.Version < 1 || order.ReceivableCents < 0 || order.ReceivableCents > maxCents {
			return fmt.Errorf("invalid order aggregate: %s", order.ID)
		}
		for _, cash := range order.Cash {
			if cash.AmountCents <= 0 || cash.AmountCents > maxCents {
				return fmt.Errorf("invalid cash amount")
			}
		}
	}
	return nil
}

func activeActor(actor Actor) bool {
	return actor.Status == "active" && actor.AuthVersion > 0 && actor.ID != "" && validActorRole(actor.Role)
}

func validActorRole(role string) bool {
	switch role {
	case "admin", "dispatcher", "engineer", "outsource", "warehouse", "qc", "finance", "customer", "supplier":
		return true
	default:
		return false
	}
}

func validateAccounts(accounts []Account) error {
	if len(accounts) == 0 {
		return fmt.Errorf("账号授权清单为空，拒绝开放业务")
	}
	ids, usernames := map[string]bool{}, map[string]bool{}
	for _, account := range accounts {
		actor := account.Actor
		for _, value := range []string{actor.ID, actor.Username, actor.Name, actor.CompanyID, account.Salt} {
			if strings.TrimSpace(value) == "" {
				return fmt.Errorf("账号授权必要字段缺失，拒绝开放业务")
			}
		}
		username := strings.ToLower(strings.TrimSpace(actor.Username))
		if ids[actor.ID] || usernames[username] {
			return fmt.Errorf("账号稳定ID或登录名重复，拒绝开放业务")
		}
		if !validActorRole(actor.Role) || (actor.Status != "active" && actor.Status != "disabled") || actor.AuthVersion < 1 {
			return fmt.Errorf("账号角色、状态或授权版本无效，拒绝开放业务")
		}
		hash, err := hex.DecodeString(account.Hash)
		if err != nil || len(hash) != sha256.Size {
			return fmt.Errorf("账号凭据摘要格式无效，拒绝开放业务")
		}
		ids[actor.ID], usernames[username] = true, true
	}
	return nil
}

func internal(actor Actor) bool {
	switch actor.Role {
	case "admin", "dispatcher", "engineer", "warehouse", "qc", "finance":
		return true
	default:
		return false
	}
}
func roles(actor Actor, allowed ...string) error {
	for _, role := range allowed {
		if actor.Role == role {
			return nil
		}
	}
	return fail(403, "forbidden", "当前角色没有此操作权限")
}
func visible(order Order, actor Actor) bool {
	switch actor.Role {
	case "customer":
		return order.CustomerID == actor.ID && order.CompanyID == actor.CompanyID && actor.CompanyID != ""
	case "supplier":
		return false
	case "engineer":
		return order.AssigneeID == actor.ID
	case "outsource":
		return order.AssigneeID == actor.ID
	default:
		return internal(actor)
	}
}
func findOrder(state *State, id string, actor Actor) (*Order, error) {
	for i := range state.Orders {
		if state.Orders[i].ID == id && visible(state.Orders[i], actor) {
			return &state.Orders[i], nil
		}
	}
	return nil, fail(404, "not_found", "工单不存在或无访问权限")
}
func findPart(state *State, id string) (*Part, error) {
	for i := range state.Parts {
		if state.Parts[i].ID == id {
			return &state.Parts[i], nil
		}
	}
	return nil, fail(422, "part_not_found", "配件不存在")
}
func accountExists(state *State, id string, allowed ...string) bool {
	for _, a := range state.Accounts {
		if a.Actor.ID == id {
			return activeActor(a.Actor) && (len(allowed) == 0 || roles(a.Actor, allowed...) == nil)
		}
	}
	return false
}
func versionCheck(actual, expected int) error {
	if expected < 1 || actual != expected {
		return fail(409, "version_conflict", "此记录已更新，请刷新后核对最新版本")
	}
	return nil
}
func amount(value int64, zero bool) error {
	if value < 0 || (!zero && value == 0) || value > maxCents {
		return fail(422, "invalid_amount", "金额须在允许范围内，按整数分填写")
	}
	return nil
}
func nowString(t time.Time) string { return t.UTC().Format(time.RFC3339) }
func parseDate(value string) (time.Time, error) {
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}, fail(422, "invalid_date", "时间须使用含时区的 RFC3339 格式")
	}
	return parsed, nil
}
func checkFiles(order Order, ids []string) bool {
	if len(ids) == 0 {
		return false
	}
	for _, id := range ids {
		found := false
		for _, e := range order.Evidence {
			if e.ID == id && !e.Deleted && (e.Data != "" || e.Text != "") {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}
func invoiceFiles(order Order, ids []string) bool {
	if !checkFiles(order, ids) {
		return false
	}
	for _, id := range ids {
		found := false
		for _, e := range order.Evidence {
			if e.ID == id && !e.Deleted && e.Data != "" && (e.MIME == "application/pdf" || e.MIME == "image/png" || e.MIME == "image/jpeg" || e.MIME == "image/gif") {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}
func (s *Service) refresh(order *Order, state *State) {
	summary := Summary{ReceivableCents: order.ReceivableCents, Missing: []string{}, WarrantyLabel: "未起保"}
	for _, cash := range order.Cash {
		if !cash.Verified {
			summary.PendingCashCents += cash.AmountCents
			continue
		}
		if cash.Kind == "receipt" {
			summary.CollectedCents += cash.AmountCents
		} else {
			summary.CollectedCents -= cash.AmountCents
		}
		if !cash.HandedOver {
			summary.Missing = append(summary.Missing, "现金内部交接未完成")
		}
	}
	summary.RemainingCents = max(int64(0), order.ReceivableCents-summary.CollectedCents)
	summary.OverpaidCents = max(int64(0), summary.CollectedCents-order.ReceivableCents)
	if summary.PendingCashCents > 0 {
		summary.Missing = append(summary.Missing, "现金待财务核实")
	}
	if summary.RemainingCents > 0 {
		summary.Missing = append(summary.Missing, "客户账款未收齐")
	}
	if summary.OverpaidCents > 0 {
		summary.Missing = append(summary.Missing, "超收或退款待处理")
	}
	if summary.CollectedCents < 0 {
		summary.Missing = append(summary.Missing, "退款超出已核实收款")
	}
	switch order.Documents.Requirement {
	case "none":
		summary.DocumentStatus = "无需，已确认"
	case "required":
		if !order.Documents.Prepared {
			summary.DocumentStatus = "未制作"
			summary.Missing = append(summary.Missing, "付款资料未制作")
		} else if !checkFiles(*order, order.Documents.Files) {
			summary.DocumentStatus = "需补附件"
			summary.Missing = append(summary.Missing, "付款资料附件缺失")
		} else if !order.Documents.Sent {
			summary.DocumentStatus = "已做未送"
			summary.Missing = append(summary.Missing, "付款资料尚未发送")
		} else {
			summary.DocumentStatus = "已发送"
		}
	default:
		summary.DocumentStatus = "待确认需求"
		summary.Missing = append(summary.Missing, "付款资料需求待确认")
	}
	invoiceFilesOK := true
	for _, invoice := range order.Invoices {
		if !invoice.Voided {
			summary.InvoiceCents += invoice.AmountCents
			if !invoiceFiles(*order, invoice.Files) {
				invoiceFilesOK = false
			}
		}
	}
	switch order.InvoiceRequirement {
	case "none":
		summary.InvoiceStatus = "无需，已确认"
	case "required":
		if summary.InvoiceCents == 0 {
			summary.InvoiceStatus = "未开"
		} else if summary.InvoiceCents < order.InvoiceDueCents {
			summary.InvoiceStatus = "部分已开"
		} else if summary.InvoiceCents > order.InvoiceDueCents {
			summary.InvoiceStatus = "超开待核实"
		} else if !invoiceFilesOK {
			summary.InvoiceStatus = "需补附件"
		} else {
			summary.InvoiceStatus = "已满足"
		}
		if summary.InvoiceCents != order.InvoiceDueCents || !invoiceFilesOK || summary.InvoiceCents == 0 {
			summary.Missing = append(summary.Missing, "发票金额或附件未满足")
		}
	default:
		summary.InvoiceStatus = "待确认需求"
		summary.Missing = append(summary.Missing, "开票需求待确认")
	}
	if order.Outcome == "" {
		summary.Missing = append(summary.Missing, "履约结果尚未明确")
	}
	for _, task := range order.Issues {
		if !task.Resolved {
			summary.Missing = append(summary.Missing, "未结异议："+task.Title)
		}
	}
	for _, task := range order.Obligations {
		if !task.Resolved {
			summary.Missing = append(summary.Missing, "待办："+task.Title)
		}
	}
	for _, cost := range order.Costs {
		if !cost.Approved {
			summary.Missing = append(summary.Missing, "成本待审核")
		}
	}
	for _, commission := range order.Commissions {
		if !commission.Settled {
			summary.Missing = append(summary.Missing, "提成待结算")
		}
	}
	for _, loan := range state.Loans {
		if loan.OrderID != order.ID {
			continue
		}
		transferred := 0
		for _, transfer := range loan.Transfers {
			transferred += transfer.Quantity
		}
		if loan.Outstanding > transferred {
			summary.Missing = append(summary.Missing, "关联配件借用尚未归还")
		}
	}
	if order.Warranty.EndsAt != "" {
		if warrantyActive(order.Warranty.EndsAt, s.now()) {
			summary.WarrantyLabel = "质保中"
		} else {
			summary.WarrantyLabel = "质保到期"
		}
	}
	summary.Missing = unique(summary.Missing)
	if len(summary.Missing) > 0 {
		summary.NextTask = strings.Join(summary.Missing, "；")
	} else {
		summary.NextTask = "负责人核对并确认整单完结"
	}
	if order.Status == "completed" {
		if len(summary.Missing) > 0 {
			summary.NextTask = "已完结 · 资料缺失待复核：" + summary.NextTask
		} else {
			summary.NextTask = "本次订单已完结，质保继续"
		}
	} else if order.Outcome != "" {
		if len(summary.Missing) == 0 {
			order.Status = "pending_completion"
		} else {
			order.Status = "settling"
		}
	} else {
		tasks := map[string]string{"pending_intake": "客服确认受理", "pending_arrangement": "安排收件、派单或上门", "diagnosis_quotation": "检测／询价并审核报价", "pending_customer_confirmation": "客户签署当前报价", "pending_execution": "核对前置条件并开始执行", "repairing": "执行维修并提交完工", "pending_quality_check": "公司质检确认", "pending_delivery": "安排完整交付", "pending_acceptance": "客户验收签署"}
		summary.NextTask = tasks[order.Status]
		for _, issue := range order.Issues {
			if !issue.Resolved {
				summary.NextTask = "阻塞：" + issue.Title
				break
			}
		}
		if order.Status == "pending_acceptance" && order.RestartReview {
			summary.NextTask = "停机期间线下异议待客服核实，自动验收暂停"
		}
	}
	order.Summary = summary
}
func unique(values []string) []string {
	seen := map[string]bool{}
	result := []string{}
	for _, v := range values {
		if !seen[v] {
			result = append(result, v)
			seen[v] = true
		}
	}
	return result
}
func (s *Service) view(order Order, state *State, actor Actor) Order {
	order = cloneOrder(order)
	s.refresh(&order, state)
	return redactOrderView(order, actor)
}

func redactOrderView(order Order, actor Actor) Order {
	order.AllowedActions = allowedActions(order, actor)
	for i := range order.Evidence {
		order.Evidence[i].Data = ""
	}
	if !internal(actor) {
		order.Remark = ""
		order.Visits = []Visit{}
		order.Outsource = []Outsource{}
		order.Costs = []Cost{}
		order.Commissions = []Commission{}
		order.Obligations = []Task{}
		events := []Event{}
		for _, event := range order.Events {
			if !event.Internal {
				events = append(events, event)
			}
		}
		order.Events = events
		evidence := []Evidence{}
		for _, e := range order.Evidence {
			if e.Public || e.UploaderID == actor.ID {
				evidence = append(evidence, e)
			}
		}
		order.Evidence = evidence
		cash := []Cash{}
		for _, c := range order.Cash {
			if c.Verified {
				c.Collector = ""
				c.VerifiedBy = ""
				cash = append(cash, c)
			}
		}
		order.Cash = cash
		order.Summary.Missing = []string{}
		order.Summary.PendingCashCents = 0
		order.Summary.NextTask = publicTask(order.Status)
		order.CompletionChecks = []string{}
	}
	filterOrderFields(&order, actor)
	return order
}
func publicTask(status string) string {
	switch status {
	case "pending_customer_confirmation":
		return "请确认报价与履约条款"
	case "pending_acceptance":
		return "请验收或反馈异议"
	case "completed":
		return "订单已完结，质保继续"
	case "settling", "pending_completion":
		return "公司正在办理资料、票据及结算"
	default:
		return "公司正在处理，请查看进度"
	}
}
func addEvent(order *Order, actor Actor, kind, title, note string, internal bool, now time.Time) {
	order.Events = append(order.Events, Event{ID: randomID("ev_"), Type: kind, Title: title, Note: note, ActorID: actor.ID, ActorName: actor.Name, At: nowString(now), Version: order.Version + 1, Internal: internal})
}

func cloneOrder(order Order) Order {
	data, _ := json.Marshal(order)
	var result Order
	_ = json.Unmarshal(data, &result)
	return result
}

func decodeBase64(value string) ([]byte, error) {
	data, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		return nil, fail(422, "invalid_base64", "文件编码无效")
	}
	return data, nil
}
