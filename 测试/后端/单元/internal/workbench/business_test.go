package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

type testPersistence struct {
	data  []byte
	fail  bool
	saves int
}

func (p *testPersistence) Load() ([]byte, error) { return append([]byte(nil), p.data...), nil }
func (p *testPersistence) Save(data []byte) error {
	if p.fail {
		return errors.New("disk unavailable")
	}
	p.data = append([]byte(nil), data...)
	p.saves++
	return nil
}
func testService(t *testing.T) (*Service, *testPersistence) {
	t.Helper()
	p := &testPersistence{}
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return s, p
}
func testActor(s *Service, id string) Actor {
	for _, a := range s.state.Accounts {
		if a.Actor.ID == id {
			return a.Actor
		}
	}
	panic("test actor not found")
}
func testOrder(t *testing.T, s *Service, id string) Order {
	t.Helper()
	s.mu.Lock()
	defer s.mu.Unlock()
	o, e := findOrder(&s.state, id, testActor(s, "admin"))
	if e != nil {
		t.Fatal(e)
	}
	return cloneOrder(*o)
}
func testAct(t *testing.T, s *Service, actor, id, kind string, payload any) (Order, error) {
	t.Helper()
	o := testOrder(t, s, id)
	return testActVersion(s, testActor(s, actor), id, kind, payload, o.Version, randomID("test_"))
}
func testActVersion(s *Service, actor Actor, id, kind string, payload any, version int, key string) (Order, error) {
	p, _ := json.Marshal(payload)
	action := Action{Type: kind, Version: version, Payload: p}
	raw, _ := json.Marshal(action)
	data, _, err := s.transact(actor, "POST /orders/"+id+"/actions", key, raw, 200, func(state *State) (any, error) { return s.act(state, actor, id, action) })
	if err != nil {
		return Order{}, err
	}
	var result Order
	err = json.Unmarshal(data, &result)
	return result, err
}
func mustAct(t *testing.T, s *Service, actor, id, kind string, p any) Order {
	t.Helper()
	o, e := testAct(t, s, actor, id, kind, p)
	if e != nil {
		t.Fatalf("%s/%s: %v", actor, kind, e)
	}
	return o
}
func expectCode(t *testing.T, err error, code string) {
	t.Helper()
	var e *businessError
	if !errors.As(err, &e) || e.Code != code {
		t.Fatalf("wanted %s, got %v", code, err)
	}
}

func TestRepairWorkflowAndFinalManualCompletion(t *testing.T) {
	s, _ := testService(t)
	a := testActor(s, "dispatcher")
	var created Order
	raw := []byte(`{"type":"mail","customer":"合成客户","customerId":"customer","companyId":"company-a","project":"合成测试","device":"控制器","description":"不能开机"}`)
	_, _, err := s.transact(a, "POST /orders", "create-normal", raw, 201, func(state *State) (any, error) {
		var input CreateOrderInput
		_ = json.Unmarshal(raw, &input)
		var e error
		created, e = s.createOrder(state, a, input)
		return created, e
	})
	if err != nil {
		t.Fatal(err)
	}
	id := created.ID
	o := mustAct(t, s, "dispatcher", id, "intake", map[string]any{"ownerId": "dispatcher", "assigneeId": "engineer"})
	if o.Status != "pending_arrangement" {
		t.Fatal(o.Status)
	}
	mustAct(t, s, "warehouse", id, "receive", map[string]any{"note": "完整设备1件，外观完好，合成收件凭据"})
	mustAct(t, s, "engineer", id, "diagnose", map[string]any{"note": "已接实物并开始检测"})
	mustAct(t, s, "engineer", id, "report", map[string]any{"note": "供电故障，拟更换模块"})
	mustAct(t, s, "engineer", id, "quote", map[string]any{"amountCents": 100000, "description": "维修与测试", "warrantyMonths": 3, "paymentTerms": "credit", "prepayCents": 0, "validUntil": nowString(s.now().Add(time.Hour)), "autoAccept": true})
	mustAct(t, s, "dispatcher", id, "approve_quote", map[string]any{"note": "合成公司批准"})
	o = mustAct(t, s, "customer", id, "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
	if o.Status != "pending_execution" {
		t.Fatal(o.Status)
	}
	mustAct(t, s, "engineer", id, "start", map[string]any{"note": "已实际开修"})
	mustAct(t, s, "engineer", id, "finish", map[string]any{"note": "更换模块，提交维修记录"})
	mustAct(t, s, "qc", id, "qc", map[string]any{"passed": true, "note": "测试结果合格"})
	o = mustAct(t, s, "warehouse", id, "dispatch", map[string]any{"carrier": "合成快递", "tracking": "DEMO-001", "note": "已实际寄出"})
	if o.Status != "pending_delivery" {
		t.Fatal("dispatch must not imply received")
	}
	mustAct(t, s, "warehouse", id, "deliver", map[string]any{"note": "客户完整实收合成凭据", "deliveredAt": nowString(s.now())})
	o = mustAct(t, s, "customer", id, "accept", map[string]any{"signature": syntheticSignature(), "passed": true, "note": "测试合格"})
	if o.Status != "settling" || o.Outcome != "accepted" || o.Warranty.StartsAt == "" {
		t.Fatalf("%+v", o)
	}
	mustAct(t, s, "dispatcher", id, "requirements", map[string]any{"documentRequirement": "none", "documentReason": "客户明确无需付款资料", "invoiceRequirement": "none", "invoiceReason": "客户明确无需票据", "invoiceDueCents": 0})
	o = mustAct(t, s, "engineer", id, "cash", map[string]any{"amountCents": 100000, "kind": "receipt", "purpose": "合成全款", "receipt": "DEMO-CASH", "occurredAt": nowString(s.now())})
	if o.Summary.CollectedCents != 0 || o.Summary.PendingCashCents != 100000 || o.Status != "settling" {
		t.Fatal("unverified cash must not settle")
	}
	cashID := o.Cash[0].ID
	o = mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": cashID})
	if o.Status != "settling" || o.Summary.CollectedCents != 100000 {
		t.Fatal("handover still blocks completion")
	}
	o = mustAct(t, s, "finance", id, "handover_cash", map[string]any{"cashId": cashID})
	if o.Status != "pending_completion" {
		t.Fatalf("missing=%v", o.Summary.Missing)
	}
	_, err = testAct(t, s, "finance", id, "complete", map[string]any{"note": "无权关单"})
	expectCode(t, err, "forbidden")
	o = mustAct(t, s, "dispatcher", id, "complete", map[string]any{"note": "核对各项真实合成事实"})
	if o.Status != "completed" || o.CompletionBy != "dispatcher" || o.Summary.WarrantyLabel != "质保中" {
		t.Fatal("final completion/warranty")
	}
	_, err = testAct(t, s, "finance", id, "adjust_receivable", map[string]any{"amountCents": 90000, "reason": "合成更正"})
	expectCode(t, err, "reopen_required")
	o = mustAct(t, s, "dispatcher", id, "reopen", map[string]any{"reason": "批准重核客户应收"})
	if o.AcceptedAt == "" || o.CompletionAt == "" || o.Status != "settling" {
		t.Fatal("reopen preserves acceptance/history")
	}
	child := mustAct(t, s, "dispatcher", id, "rework", map[string]any{"note": "验收后关联返修，合成故障", "free": true})
	if child.OriginalOrderID != id || child.Status != "pending_intake" {
		t.Fatal("rework should be separate")
	}
}

func TestVersionIdempotencyAndFailedSaveAreAtomic(t *testing.T) {
	s, p := testService(t)
	o := testOrder(t, s, "wo_intake")
	payload := map[string]any{"ownerId": "dispatcher", "assigneeId": "engineer"}
	first, err := testActVersion(s, testActor(s, "dispatcher"), o.ID, "intake", payload, o.Version, "one-confirmation")
	if err != nil {
		t.Fatal(err)
	}
	second, err := testActVersion(s, testActor(s, "dispatcher"), o.ID, "intake", payload, o.Version, "one-confirmation")
	if err != nil || second.Version != first.Version {
		t.Fatal("same request must not double mutate")
	}
	_, err = testActVersion(s, testActor(s, "dispatcher"), o.ID, "intake", payload, o.Version, "stale-new-key")
	expectCode(t, err, "version_conflict")
	_, err = testActVersion(s, testActor(s, "dispatcher"), o.ID, "intake", map[string]any{"ownerId": "admin", "assigneeId": "engineer"}, o.Version, "one-confirmation")
	expectCode(t, err, "idempotency_conflict")
	before := testOrder(t, s, o.ID)
	saved := append([]byte(nil), p.data...)
	p.fail = true
	_, err = testAct(t, s, "engineer", o.ID, "diagnose", map[string]any{"note": "不会留下半套"})
	if err == nil {
		t.Fatal("save failure expected")
	}
	after := testOrder(t, s, o.ID)
	if before.Version != after.Version || before.Status != after.Status || !bytes.Equal(saved, p.data) {
		t.Fatal("failed persist changed in-memory state")
	}
}

func TestSignaturesAndExpiredAcceptedQuote(t *testing.T) {
	s, _ := testService(t)
	blank := image.NewRGBA(image.Rect(0, 0, 160, 64))
	for y := 0; y < 64; y++ {
		for x := 0; x < 160; x++ {
			blank.Set(x, y, color.White)
		}
	}
	var buffer bytes.Buffer
	_ = png.Encode(&buffer, blank)
	signature := "data:image/png;base64," + base64.StdEncoding.EncodeToString(buffer.Bytes())
	_, err := testAct(t, s, "customer", "wo_quote", "sign_quote", map[string]any{"signature": signature, "quoteVersion": 1})
	expectCode(t, err, "empty_signature")
	_, err = testAct(t, s, "admin", "wo_quote", "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
	expectCode(t, err, "forbidden")
	_, err = testAct(t, s, "customer", "wo_quote", "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 2})
	expectCode(t, err, "quote_version_conflict")
	mustAct(t, s, "customer", "wo_quote", "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
	s.now = func() time.Time { return time.Now().Add(120 * time.Hour) }
	o := mustAct(t, s, "engineer", "wo_quote", "start", map[string]any{"note": "到期前已签，按冻结条款履约"})
	if o.Status != "repairing" {
		t.Fatal(o.Status)
	}
}

func TestInvoiceExactAmountRealFilesAndDeletion(t *testing.T) {
	s, _ := testService(t)
	id := "wo_ready"
	mustAct(t, s, "dispatcher", id, "requirements", map[string]any{"documentRequirement": "none", "documentReason": "无需资料", "invoiceRequirement": "required", "invoiceReason": "客户约定票额500元", "invoiceDueCents": 50000})
	o := mustAct(t, s, "finance", id, "evidence", map[string]any{"name": "不能充当发票.txt", "kind": "text", "text": "文字不等于票据原件", "mime": "text/plain"})
	bad := o.Evidence[len(o.Evidence)-1].ID
	_, err := testAct(t, s, "finance", id, "invoice", map[string]any{"number": "DEMO-TEXT", "amountCents": 50000, "files": []string{bad}})
	expectCode(t, err, "invoice_files_required")
	pdf := base64.StdEncoding.EncodeToString([]byte("%PDF-1.4\n% synthetic test invoice only\n%%EOF\n"))
	o = mustAct(t, s, "finance", id, "evidence", map[string]any{"name": "合成发票.pdf", "kind": "document", "mime": "application/pdf", "data": pdf})
	file := o.Evidence[len(o.Evidence)-1].ID
	o = mustAct(t, s, "finance", id, "invoice", map[string]any{"number": "DEMO-A", "amountCents": 30000, "files": []string{file}})
	if o.Status != "settling" {
		t.Fatal("partial invoice must block")
	}
	o = mustAct(t, s, "finance", id, "invoice", map[string]any{"number": "DEMO-B", "amountCents": 30000, "files": []string{file}})
	if o.Summary.InvoiceStatus != "超开待核实" || o.Status != "settling" {
		t.Fatal("overinvoice must block")
	}
	mustAct(t, s, "finance", id, "void_invoice", map[string]any{"invoiceId": o.Invoices[len(o.Invoices)-1].ID, "reason": "合成红冲更正"})
	o = mustAct(t, s, "finance", id, "invoice", map[string]any{"number": "DEMO-C", "amountCents": 20000, "files": []string{file}})
	if o.Status != "pending_completion" {
		t.Fatalf("%v", o.Summary.Missing)
	}
	mustAct(t, s, "dispatcher", id, "complete", map[string]any{"note": "完成核对"})
	o = mustAct(t, s, "finance", id, "delete_evidence", map[string]any{"evidenceId": file, "reason": "上传者删除合成票据"})
	if o.Status != "completed" || !strings.Contains(o.Summary.NextTask, "资料缺失待复核") {
		t.Fatal("must preserve completion history and expose missing evidence")
	}
	if invoiceFiles(testOrder(t, s, id), []string{file}) {
		t.Fatal("deleted files cannot satisfy invoice")
	}
}

func TestLoansConservationTransferAndConcurrentBorrow(t *testing.T) {
	s, _ := testService(t)
	actor := testActor(s, "admin")
	input := LoanInput{OrderID: "wo_ready", PartID: "part-board", Quantity: 5, BorrowerID: "engineer", DueAt: nowString(s.now().Add(24 * time.Hour)), Note: "合成批准借出"}
	raw, _ := json.Marshal(input)
	data, _, err := s.transact(actor, "POST /loans", "borrow-five", raw, 201, func(state *State) (any, error) { return s.createLoan(state, actor, input) })
	if err != nil {
		t.Fatal(err)
	}
	var loan Loan
	_ = json.Unmarshal(data, &loan)
	act := func(kind string, payload loanPayload) {
		t.Helper()
		p, _ := json.Marshal(payload)
		a := Action{Type: kind, Version: loan.Version, Payload: p}
		raw, _ := json.Marshal(a)
		d, _, e := s.transact(actor, "POST /loans/"+loan.ID, randomID("k_"), raw, 200, func(state *State) (any, error) { return s.loanAction(state, actor, loan.ID, a) })
		if e != nil {
			t.Fatal(e)
		}
		_ = json.Unmarshal(d, &loan)
	}
	act("return", loanPayload{Quantity: 2, Condition: "good"})
	act("return", loanPayload{Quantity: 1, Condition: "quarantine"})
	act("consume", loanPayload{Quantity: 1, Reason: "已批准安装耗用与成本依据"})
	if loan.Outstanding != 1 || loan.Quantity != loan.ReturnedGood+loan.ReturnedQuarantine+loan.Consumed+loan.Disposed+loan.Outstanding {
		t.Fatal("loan conservation")
	}
	part, _ := findPart(&s.state, "part-board")
	if part.Available != 25 || part.Quarantine != 2 {
		t.Fatalf("inventory %v", part)
	}
	o := testOrder(t, s, "wo_ready")
	s.refresh(&o, &s.state)
	if o.Status != "settling" {
		t.Fatal("uncleared linked loan blocks")
	}
	act("transfer", loanPayload{Quantity: 1, OwnerID: "engineer", DueAt: nowString(s.now().Add(48 * time.Hour)), Reason: "批准转独立跟踪，责任与期限明确"})
	if loan.Outstanding != 1 || part.Available != 25 {
		t.Fatal("transfer must not alter stock/debt")
	}
	o = testOrder(t, s, "wo_ready")
	s.refresh(&o, &s.state)
	if o.Status != "pending_completion" {
		t.Fatalf("%v", o.Summary.Missing)
	}
	act("return", loanPayload{Quantity: 1, Condition: "good"})
	if loan.Outstanding != 0 {
		t.Fatal("later return must clear original item")
	}
	// Two concurrent requests cannot each take the last stock.
	s.mu.Lock()
	s.state.Parts[1].Available = 1
	s.mu.Unlock()
	success := 0
	var mu sync.Mutex
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			in := LoanInput{PartID: "part-sensor", Quantity: 1, BorrowerID: "engineer", DueAt: nowString(time.Now().Add(time.Hour)), Note: "并发借出合成凭据"}
			raw, _ := json.Marshal(in)
			_, _, e := s.transact(actor, "POST /loans", randomID("c_"), raw, 201, func(state *State) (any, error) { return s.createLoan(state, actor, in) })
			if e == nil {
				mu.Lock()
				success++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if success != 1 || s.state.Parts[1].Available != 0 {
		t.Fatal("concurrent borrow oversold stock")
	}
}

func TestFailureRequiresRefundAndReturnWithoutFakeAcceptance(t *testing.T) {
	s, _ := testService(t)
	id := "wo_quote"
	o := mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": 30000, "kind": "receipt", "purpose": "合成预付", "receipt": "DEMO-PRE", "occurredAt": nowString(s.now())})
	cash := o.Cash[0].ID
	mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": cash})
	mustAct(t, s, "finance", id, "handover_cash", map[string]any{"cashId": cash})
	mustAct(t, s, "dispatcher", id, "requirements", map[string]any{"documentRequirement": "none", "documentReason": "停止协议无需资料", "invoiceRequirement": "none", "invoiceReason": "无费用无需票据", "invoiceDueCents": 0})
	o = mustAct(t, s, "dispatcher", id, "failure", map[string]any{"reason": "unrepairable", "note": "合成检测报告、公司批准并通知客户", "amountCents": 0, "returnRequired": true})
	if o.Status != "settling" || o.Outcome != "failed" || o.AcceptedAt != "" || o.Warranty.StartsAt != "" || o.Summary.OverpaidCents != 30000 {
		t.Fatal("failure is not accepted or completed")
	}
	o = mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": 30000, "kind": "refund", "purpose": "批准退还预付", "receipt": "DEMO-REFUND", "occurredAt": nowString(s.now())})
	refund := o.Cash[len(o.Cash)-1].ID
	mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": refund})
	mustAct(t, s, "finance", id, "handover_cash", map[string]any{"cashId": refund})
	o = mustAct(t, s, "warehouse", id, "resolve_obligation", map[string]any{"obligationId": o.Obligations[0].ID, "note": "完整设备退还，客户实收凭据"})
	if o.Status != "pending_completion" {
		t.Fatalf("%v", o.Summary.Missing)
	}
	o = mustAct(t, s, "dispatcher", id, "complete", map[string]any{"note": "失败余项核对完毕"})
	if o.Outcome != "failed" || o.Warranty.StartsAt != "" {
		t.Fatal("failure closure fabricated warranty")
	}
}

func TestAutomaticAcceptanceCalendarAndRestartReview(t *testing.T) {
	s, p := testService(t)
	fixed, _ := time.Parse(time.RFC3339, "2026-10-13T00:00:00+08:00")
	s.now = func() time.Time { return fixed }
	s.mu.Lock()
	o, _ := findOrder(&s.state, "wo_quote", testActor(s, "admin"))
	o.Status = "pending_delivery"
	o.Quote = seedSignedQuote(fixed, 128000, "合成报价", true)
	s.mu.Unlock()
	o2 := mustAct(t, s, "warehouse", "wo_quote", "deliver", map[string]any{"note": "合成完整签收依据", "deliveredAt": "2026-10-06T21:33:00+08:00"})
	if o2.AcceptanceDueAt != "2026-10-12T16:00:00Z" {
		t.Fatal(o2.AcceptanceDueAt)
	}
	s2, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	s2.now = func() time.Time { return fixed }
	if err = s2.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	if testOrder(t, s2, o2.ID).Outcome != "" {
		t.Fatal("restart must check offline objections")
	}
	mustAct(t, s2, "dispatcher", o2.ID, "review_acceptance", map[string]any{"note": "客户确认停机期间无异议，线下联系合成凭据"})
	if err = s2.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	accepted := testOrder(t, s2, o2.ID)
	if accepted.Outcome != "accepted" || accepted.AcceptanceMode != "system_auto_acceptance" || accepted.AcceptanceSignature != "" || accepted.AcceptedAt != o2.AcceptanceDueAt {
		t.Fatal("automatic acceptance evidence/effective time")
	}
	version := accepted.Version
	if err = s2.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	if testOrder(t, s2, o2.ID).Version != version {
		t.Fatal("automatic acceptance repeated")
	}
}

func TestHTTPPermissionsPrivateDownloadAndRevocation(t *testing.T) {
	s, _ := testService(t)
	handler := s.Handler("")
	login := func(id string) string {
		token, _, err := s.login(id, "Demo-Repair-2026!", "test")
		if err != nil {
			t.Fatal(err)
		}
		return token
	}
	admin := login("admin")
	customer := login("customer")
	customerB := login("customer-b")
	get := func(path, token string) *httptest.ResponseRecorder {
		r := httptest.NewRequest("GET", path, nil)
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	if get("/api/v38/orders", "").Code != 401 || get("/api/v38/orders/wo_quote", customerB).Code != 404 {
		t.Fatal("anonymous/cross-company access")
	}
	w := get("/api/v38/orders/wo_repair", customer)
	if w.Code != 200 || strings.Contains(w.Body.String(), "内部差旅") || strings.Contains(w.Body.String(), "内部交接说明") {
		t.Fatal("private notes leaked")
	}
	if get("/api/v38/orders/wo_settling/evidence/file_report", customer).Code != 200 {
		t.Fatal("published report should download")
	}
	if get("/api/v38/orders/wo_settling/evidence/file_report", customerB).Code != 404 {
		t.Fatal("cross-company attachment")
	}
	w = get("/api/v38/export", admin)
	if w.Code != 200 || strings.Contains(w.Body.String(), "\"salt\"") || strings.Contains(w.Body.String(), "\"hash\"") || strings.Contains(w.Body.String(), "Demo-Repair-2026!") {
		t.Fatal("account credentials leaked through export")
	}
	s.mu.Lock()
	for i := range s.state.Accounts {
		if s.state.Accounts[i].Actor.ID == "customer" {
			s.state.Accounts[i].Actor.Status = "disabled"
		}
	}
	s.mu.Unlock()
	if get("/api/v38/orders", customer).Code != http.StatusUnauthorized {
		t.Fatal("disabled old session remains valid")
	}
}

func TestContactHandoverIsPerOrderAndPreservesSignature(t *testing.T) {
	s, _ := testService(t)
	peer := testActor(s, "customer-peer")
	admin := testActor(s, "admin")
	if visible(testOrder(t, s, "wo_quote"), peer) {
		t.Fatal("same company alone must not grant order authorization")
	}
	o := mustAct(t, s, "customer", "wo_quote", "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
	signer := o.Quote.Signer
	signedAt := o.Quote.SignedAt
	_, err := testAct(t, s, "dispatcher", "wo_quote", "handover_contact", map[string]any{"customerId": "customer-b", "reason": "跨公司非法交接"})
	expectCode(t, err, "cross_company")
	o = mustAct(t, s, "dispatcher", "wo_quote", "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成企业授权接替，原联系人离职"})
	if o.CustomerID != peer.ID || o.Quote.Signer != signer || o.Quote.SignedAt != signedAt {
		t.Fatal("handover must not change original signing snapshot")
	}
	if visible(o, testActor(s, "customer")) || !visible(o, peer) {
		t.Fatal("handover did not revoke only original order contact")
	}
	if !visible(testOrder(t, s, "wo_ready"), testActor(s, "customer")) {
		t.Fatal("other original contact order must remain available")
	}
	if _, err = findOrder(&s.state, "wo_quote", testActor(s, "customer")); err == nil {
		t.Fatal("old contact can still download/get")
	}
	if _, err = findOrder(&s.state, "wo_quote", peer); err != nil {
		t.Fatal(err)
	}
	if !visible(testOrder(t, s, "wo_quote"), admin) {
		t.Fatal("admin lost order")
	}
}

func TestReenabledAccountCannotReviveOldSession(t *testing.T) {
	s, _ := testService(t)
	handler := s.Handler("")
	old, _, err := s.login("customer", "Demo-Repair-2026!", "test")
	if err != nil {
		t.Fatal(err)
	}
	admin, _, err := s.login("admin", "Demo-Repair-2026!", "test")
	if err != nil {
		t.Fatal(err)
	}
	for _, status := range []string{"disabled", "active"} {
		r := httptest.NewRequest("POST", "/api/v38/accounts/customer/status", strings.NewReader(`{"status":"`+status+`","reason":"合成权限变更"}`))
		r.Header.Set("Authorization", "Bearer "+admin)
		r.Header.Set("Idempotency-Key", randomID("test_"))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code != 200 {
			t.Fatalf("status update %d %s", w.Code, w.Body.String())
		}
	}
	if _, err = s.authenticate(old); err == nil {
		t.Fatal("re-enable revived old session")
	}
	if _, _, err = s.login("customer", "Demo-Repair-2026!", "test"); err != nil {
		t.Fatal("new login should work after enable", err)
	}
}
