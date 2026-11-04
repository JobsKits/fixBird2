package workbench

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"
)

func prepaymentOrder(t *testing.T, s *Service, kind, terms string, prepay int64, agreement *bool) Order {
	t.Helper()
	actor := testActor(s, "dispatcher")
	input := CreateOrderInput{Type: kind, Customer: "合成先款客户", CustomerID: "customer", CompanyID: "company-a", Project: "先款开修合同验证", Device: "合成控制器", Description: "验证经确认的先款执行规则"}
	raw, err := json.Marshal(input)
	if err != nil {
		t.Fatal(err)
	}
	result, _, err := s.transact(actor, "POST /api/v38/orders", randomID("create_"), raw, 201, func(next *State) (any, error) { return s.createOrder(next, actor, input) })
	if err != nil {
		t.Fatal(err)
	}
	o := acceptanceResponse(t, result)
	mustAct(t, s, "dispatcher", o.ID, "intake", map[string]any{"ownerId": "dispatcher", "assigneeId": "engineer"})
	mustAct(t, s, "engineer", o.ID, "diagnose", map[string]any{"note": "合成检测或销售询价"})
	payload := map[string]any{"amountCents": 100000, "description": "合成维修或销售范围", "warrantyMonths": 3, "paymentTerms": terms, "prepayCents": prepay, "validUntil": nowString(s.now().Add(time.Hour))}
	if agreement != nil {
		payload["startRequiresPrepayment"] = *agreement
	}
	mustAct(t, s, "engineer", o.ID, "quote", payload)
	mustAct(t, s, "dispatcher", o.ID, "approve_quote", map[string]any{"note": "按明确约定审核"})
	return mustAct(t, s, "customer", o.ID, "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
}

func prepaymentCash(t *testing.T, s *Service, id, kind string, cents int64, verified bool) string {
	t.Helper()
	o := mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": cents, "kind": kind, "purpose": "合成先款合同", "receipt": randomID("receipt_"), "occurredAt": nowString(s.now())})
	cashID := o.Cash[len(o.Cash)-1].ID
	if verified {
		mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": cashID})
	}
	return cashID
}

func TestRepairStartOnlyRequiresExplicitPrepaymentAgreement(t *testing.T) {
	yes, no := true, false
	for _, tc := range []struct {
		name, kind, terms string
		prepay            int64
		agreement         *bool
	}{
		{"legacy_cash_repair_without_flag", "mail", "cash", 0, nil},
		{"legacy_positive_prepay_is_not_start_agreement", "mail", "cash", 30000, nil},
		{"explicit_no_agreement_cash", "mail", "cash", 30000, &no},
		{"explicit_no_agreement_credit", "mail", "credit", 30000, &no},
		{"onsite_without_agreement", "onsite", "cash", 0, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, p := testService(t)
			o := prepaymentOrder(t, s, tc.kind, tc.terms, tc.prepay, tc.agreement)
			if o.Quote.StartRequiresPrepayment {
				t.Fatal("missing/false agreement promoted to true")
			}
			// A restart must not infer a new obligation from cash terms or an old prepay amount.
			s, err := New(p)
			if err != nil {
				t.Fatal(err)
			}
			started := mustAct(t, s, "engineer", o.ID, "start", map[string]any{"note": "未约定先款，实际开修"})
			if started.Status != "repairing" || started.Summary.CollectedCents != 0 {
				t.Fatal("unagreed payment blocked start")
			}
		})
	}
	for _, terms := range []string{"cash", "credit"} {
		t.Run("agreed_"+terms+"_verified_net_amount", func(t *testing.T) {
			s, p := testService(t)
			o := prepaymentOrder(t, s, "mail", terms, 30000, &yes)
			if !o.Quote.StartRequiresPrepayment {
				t.Fatal("agreement lost before signature")
			}
			reject := func() {
				t.Helper()
				before := append([]byte{}, p.data...)
				_, err := testAct(t, s, "engineer", o.ID, "start", map[string]any{"note": "合成应被先款约定阻塞"})
				expectCode(t, err, "prepayment_required")
				if !bytes.Equal(before, p.data) {
					t.Fatal("blocked start changed persistence")
				}
			}
			reject()
			cashID := prepaymentCash(t, s, o.ID, "receipt", 30000, false)
			reject()
			mustAct(t, s, "finance", o.ID, "verify_cash", map[string]any{"cashId": cashID})
			prepaymentCash(t, s, o.ID, "refund", 10000, true)
			reject()
			prepaymentCash(t, s, o.ID, "receipt", 10000, true)
			started := mustAct(t, s, "engineer", o.ID, "start", map[string]any{"note": "财务核实净收达到约定预款，实际开修"})
			if started.Status != "repairing" || started.Summary.CollectedCents != 30000 || !started.Quote.StartRequiresPrepayment {
				t.Fatal("verified prepayment did not permit repair", started.Summary)
			}
		})
	}
}

func TestSalesPaymentGateUnchangedByRepairAgreement(t *testing.T) {
	yes, no := true, false
	for _, tc := range []struct {
		name, terms       string
		prepay, threshold int64
		agreement         *bool
	}{
		{"cash_legacy_full_amount", "cash", 0, 100000, nil},
		{"cash_false_flag_still_full_amount", "cash", 20000, 100000, &no},
		{"cash_true_flag_cannot_reduce_sale_gate", "cash", 20000, 100000, &yes},
		{"credit_existing_prepay_gate", "credit", 20000, 20000, &no},
		{"credit_without_prepay", "credit", 0, 0, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := testService(t)
			o := prepaymentOrder(t, s, "sale", tc.terms, tc.prepay, tc.agreement)
			stock := func() (Order, error) {
				return testAct(t, s, "warehouse", o.ID, "stock_ready", map[string]any{"partId": "part-board", "quantity": 1, "note": "合成实际出库"})
			}
			part, _ := findPart(&s.state, "part-board")
			before := part.Available
			if tc.threshold > 0 {
				_, err := stock()
				expectCode(t, err, "prepayment_required")
				prepaymentCash(t, s, o.ID, "receipt", tc.threshold-1, true)
				_, err = stock()
				expectCode(t, err, "prepayment_required")
				part, _ := findPart(&s.state, "part-board")
				if part.Available != before {
					t.Fatal("rejected stock-out changed inventory")
				}
				prepaymentCash(t, s, o.ID, "receipt", 1, true)
			}
			out, err := stock()
			if err != nil || out.Status != "pending_delivery" {
				t.Fatal("sale gate changed", err)
			}
			part, _ = findPart(&s.state, "part-board")
			if part.Available != before-1 {
				t.Fatal("sale stock-out missing")
			}
		})
	}
}

func TestWarrantyAndPrepaymentInputBoundsAreAtomic(t *testing.T) {
	s, p := testService(t)
	o := testOrder(t, s, "wo_quote")
	for _, months := range []int{0, -1, 61, int(^uint(0) >> 1)} {
		t.Run(fmt.Sprintf("months_%d", months), func(t *testing.T) {
			before := append([]byte{}, p.data...)
			_, err := testAct(t, s, "engineer", o.ID, "quote", map[string]any{"amountCents": 100000, "description": "合成质保边界", "warrantyMonths": months, "paymentTerms": "credit", "prepayCents": 0, "validUntil": nowString(s.now().Add(time.Hour))})
			expectCode(t, err, "invalid_quote")
			if !bytes.Equal(before, p.data) {
				t.Fatal("invalid months changed persistence")
			}
		})
	}
	for _, prepay := range []int64{0, -1, 100001} {
		t.Run(fmt.Sprintf("agreed_prepay_%d", prepay), func(t *testing.T) {
			before := append([]byte{}, p.data...)
			_, err := testAct(t, s, "engineer", o.ID, "quote", map[string]any{"amountCents": 100000, "description": "合成先款边界", "warrantyMonths": 3, "paymentTerms": "cash", "prepayCents": prepay, "startRequiresPrepayment": true, "validUntil": nowString(s.now().Add(time.Hour))})
			expectCode(t, err, "invalid_quote")
			if !bytes.Equal(before, p.data) {
				t.Fatal("invalid prepay changed persistence")
			}
		})
	}
	engineer := secondPermissionToken(t, s, "engineer")
	for _, field := range []string{`"warrantyMonths":1.5`, `"warrantyMonths":9223372036854775808`, `"startRequiresPrepayment":"true"`} {
		t.Run("strict_"+field, func(t *testing.T) {
			before := append([]byte{}, p.data...)
			body := []byte(fmt.Sprintf(`{"type":"quote","version":%d,"payload":{%s}}`, o.Version, field))
			w := secondPermissionHTTP(s, engineer, http.MethodPost, "/api/v38/orders/"+o.ID+"/actions", randomID("strict_"), body)
			if w.Code != http.StatusUnprocessableEntity || !bytes.Contains(w.Body.Bytes(), []byte(`"error":"invalid_json"`)) || !bytes.Equal(before, p.data) {
				t.Fatalf("invalid scalar rejection/atomicity mismatch status=%d body=%s", w.Code, w.Body.String())
			}
		})
	}
}

func TestWarrantyLeapCutoffAndHistoricalEndDate(t *testing.T) {
	s, _ := testService(t)
	o := r4Delivery(t, s, r4Time(t, "2024-01-31T02:00:00+08:00"), 1, false)
	mustAct(t, s, "customer", o.ID, "accept", map[string]any{"passed": true, "signature": syntheticSignature()})
	for _, tc := range []struct{ now, want string }{
		{"2024-02-28T23:59:59Z", "质保中"},
		{"2024-02-29T15:59:59Z", "质保中"},
		{"2024-02-29T16:00:00Z", "质保到期"},
	} {
		t.Run(tc.now, func(t *testing.T) {
			s.now = func() time.Time { return r4Time(t, tc.now) }
			viewed := s.view(testOrder(t, s, o.ID), &s.state, testActor(s, "customer"))
			if viewed.Summary.WarrantyLabel != tc.want || viewed.Warranty.EndsAt != "2024-02-28T18:00:00Z" {
				t.Fatal("leap-date coverage mismatch", viewed.Warranty, viewed.Summary.WarrantyLabel)
			}
		})
	}
	// A previously agreed/stored end is not recomputed from the quote or acceptance.
	historical := testOrder(t, s, o.ID)
	historical.Warranty.EndsAt = "2024-03-02T18:00:00Z"
	s.now = func() time.Time { return r4Time(t, "2024-03-03T23:59:59+08:00") }
	viewed := s.view(historical, &s.state, testActor(s, "customer"))
	if viewed.Warranty.EndsAt != historical.Warranty.EndsAt || viewed.Summary.WarrantyLabel != "质保中" {
		t.Fatal("historical agreed end changed", viewed.Warranty)
	}
}

func TestWarrantyDateRangeFailureIsAtomicForManualAndAuto(t *testing.T) {
	for _, auto := range []bool{false, true} {
		t.Run(fmt.Sprintf("auto_%t", auto), func(t *testing.T) {
			s, p := testService(t)
			clock := r4Time(t, "9998-12-31T10:00:00+08:00")
			o := r4Delivery(t, s, clock, 60, auto)
			before := append([]byte{}, p.data...)
			var err error
			if auto {
				deadline := r4Time(t, o.AcceptanceDueAt)
				s.now = func() time.Time { return deadline.Add(time.Hour) }
				err = s.SweepAutoAcceptance()
			} else {
				_, err = testAct(t, s, "customer", o.ID, "accept", map[string]any{"passed": true, "signature": syntheticSignature()})
			}
			expectCode(t, err, "invalid_warranty")
			current := testOrder(t, s, o.ID)
			if !bytes.Equal(before, p.data) || current.Outcome != "" || current.AcceptedAt != "" || len(current.AcceptanceRecords) != 0 || current.Warranty != (Warranty{}) {
				t.Fatal("unrepresentable warranty partially committed")
			}
		})
	}
}
