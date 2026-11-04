package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"strings"
	"testing"
	"time"
)

func r4Time(t *testing.T, value string) time.Time {
	t.Helper()
	result, err := time.Parse(time.RFC3339, value)
	if err != nil {
		t.Fatal(err)
	}
	return result
}

// Use actual committed business actions. Only the wall clock is controlled.
func r4Delivery(t *testing.T, s *Service, now time.Time, months int, auto bool) Order {
	t.Helper()
	s.now = func() time.Time { return now }
	id := "wo_quote"
	mustAct(t, s, "engineer", id, "quote", map[string]any{"amountCents": 128000, "description": "独立合成边界：维修与测试", "warrantyMonths": months, "paymentTerms": "credit", "prepayCents": 0, "validUntil": nowString(now.Add(time.Hour)), "autoAccept": auto})
	mustAct(t, s, "dispatcher", id, "approve_quote", map[string]any{"note": "合成批准"})
	mustAct(t, s, "customer", id, "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 2})
	mustAct(t, s, "engineer", id, "start", map[string]any{"note": "实际开始"})
	mustAct(t, s, "engineer", id, "finish", map[string]any{"note": "合成完工报告"})
	mustAct(t, s, "qc", id, "qc", map[string]any{"passed": true, "note": "合成质检通过"})
	return mustAct(t, s, "warehouse", id, "deliver", map[string]any{"note": "合成完整实收依据", "deliveredAt": nowString(now)})
}

func TestR4BackendManualWarrantyCalendar(t *testing.T) {
	cases := []struct {
		name, start, want string
		months            int
	}{
		{"regular", "2026-10-06T10:00:00+08:00", "2027-01-06T02:00:00Z", 3},
		{"nonleap_month_end", "2026-01-31T10:00:00+08:00", "2026-04-30T02:00:00Z", 3},
		{"leap_february", "2024-01-31T10:00:00+08:00", "2024-02-29T02:00:00Z", 1},
		{"china_date_across_utc", "2026-01-31T02:00:00+08:00", "2026-02-27T18:00:00Z", 1},
		{"nonleap_february", "2026-01-31T10:00:00+08:00", "2026-02-28T02:00:00Z", 1},
		{"thirty_day_source", "2026-04-30T10:00:00+08:00", "2026-05-30T02:00:00Z", 1},
		{"year_boundary", "2026-12-31T10:00:00+08:00", "2027-01-31T02:00:00Z", 1},
		{"maximum_contract_months", "2024-02-29T10:00:00+08:00", "2029-02-28T02:00:00Z", 60},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s, p := testService(t)
			now := r4Time(t, tc.start)
			o := r4Delivery(t, s, now, tc.months, false)
			accepted := mustAct(t, s, "customer", o.ID, "accept", map[string]any{"passed": true, "signature": syntheticSignature(), "note": "合成验收通过"})
			var persisted State
			if err := json.Unmarshal(p.data, &persisted); err != nil {
				t.Fatal(err)
			}
			disk, _ := findOrder(&persisted, o.ID, testActor(s, "admin"))
			t.Logf("start=%s months=%d end=%s expected=%s persisted=%s", tc.start, tc.months, accepted.Warranty.EndsAt, tc.want, disk.Warranty.EndsAt)
			if accepted.Warranty.EndsAt != tc.want || disk.Warranty.EndsAt != tc.want {
				t.Fatalf("calendar-month warranty mismatch: got=%s want=%s", accepted.Warranty.EndsAt, tc.want)
			}
		})
	}
}

func TestR4BackendAutoWarrantyCalendar(t *testing.T) {
	s, _ := testService(t)
	delivered := r4Time(t, "2026-01-24T12:00:00+08:00")
	o := r4Delivery(t, s, delivered, 3, true)
	deadline := r4Time(t, o.AcceptanceDueAt)
	s.now = func() time.Time { return deadline.Add(time.Minute) }
	if err := s.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	accepted := testOrder(t, s, o.ID)
	want := "2026-04-29T16:00:00Z"
	t.Logf("delivered=%s deadline=%s accepted=%s end=%s expected=%s", nowString(delivered), o.AcceptanceDueAt, accepted.AcceptedAt, accepted.Warranty.EndsAt, want)
	if accepted.AcceptanceMode != "system_auto_acceptance" || accepted.Warranty.EndsAt != want {
		t.Fatalf("auto acceptance warranty mismatch: got=%s want=%s", accepted.Warranty.EndsAt, want)
	}
}

func TestR4BackendWarrantyInclusiveFinalDay(t *testing.T) {
	cases := []struct{ name, now, want string }{
		{"cutoff_day_before_original_clock", "2027-01-06T09:59:59+08:00", "质保中"},
		{"cutoff_day_exact_original_clock", "2027-01-06T10:00:00+08:00", "质保中"},
		{"cutoff_day_last_second", "2027-01-06T23:59:59+08:00", "质保中"},
		{"next_day_midnight", "2027-01-07T00:00:00+08:00", "质保到期"},
		{"utc_previous_date_same_final_day", "2027-01-05T23:00:00Z", "质保中"},
		{"utc_final_day_last_instant", "2027-01-06T15:59:59Z", "质保中"},
		{"utc_china_next_day", "2027-01-06T16:00:00Z", "质保到期"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := testService(t)
			now := r4Time(t, "2026-10-06T10:00:00+08:00")
			o := r4Delivery(t, s, now, 3, false)
			mustAct(t, s, "customer", o.ID, "accept", map[string]any{"passed": true, "signature": syntheticSignature()})
			s.now = func() time.Time { return r4Time(t, tc.now) }
			viewed := s.view(testOrder(t, s, o.ID), &s.state, testActor(s, "customer"))
			t.Logf("now=%s end=%s label=%s expected=%s", tc.now, viewed.Warranty.EndsAt, viewed.Summary.WarrantyLabel, tc.want)
			if viewed.Summary.WarrantyLabel != tc.want {
				t.Fatalf("cutoff day prematurely expired: got=%s want=%s", viewed.Summary.WarrantyLabel, tc.want)
			}
		})
	}
}

func TestR4BackendCompetingRefundsAndRetryAtomicity(t *testing.T) {
	s, p := testService(t)
	id := "wo_ready"
	first := mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": 30000, "kind": "refund", "purpose": "合成第一笔退款", "receipt": "R4-R1", "occurredAt": nowString(s.now())})
	firstID := first.Cash[len(first.Cash)-1].ID
	second := mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": 30000, "kind": "refund", "purpose": "合成第二笔退款", "receipt": "R4-R2", "occurredAt": nowString(s.now())})
	secondID := second.Cash[len(second.Cash)-1].ID
	verified := mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": firstID})
	t.Run("net_receipts_updated", func(t *testing.T) {
		if verified.Summary.CollectedCents != 20000 {
			t.Fatal(verified.Summary)
		}
	})
	before := string(p.data)
	key := "r4-refund-retry"
	_, err := testActVersion(s, testActor(s, "finance"), id, "verify_cash", map[string]any{"cashId": secondID}, verified.Version, key)
	t.Run("over_refund_rejected_atomically", func(t *testing.T) {
		expectCode(t, err, "refund_exceeds_receipts")
		if string(p.data) != before {
			t.Fatal("rejected refund changed persistence")
		}
	})
	// Failed request must stay unconsumed; after an intervening real receipt, its stale version must conflict.
	next := mustAct(t, s, "finance", id, "cash", map[string]any{"amountCents": 10000, "kind": "receipt", "purpose": "合成补款", "receipt": "R4-REC", "occurredAt": nowString(s.now())})
	receiptID := next.Cash[len(next.Cash)-1].ID
	mustAct(t, s, "finance", id, "verify_cash", map[string]any{"cashId": receiptID})
	_, err = testActVersion(s, testActor(s, "finance"), id, "verify_cash", map[string]any{"cashId": secondID}, verified.Version, key)
	t.Run("failed_key_not_consumed", func(t *testing.T) { expectCode(t, err, "version_conflict") })
	current := testOrder(t, s, id)
	final, err := testActVersion(s, testActor(s, "finance"), id, "verify_cash", map[string]any{"cashId": secondID}, current.Version, key)
	t.Run("new_version_same_unconsumed_key_succeeds", func(t *testing.T) {
		if err != nil || final.Summary.CollectedCents != 0 {
			t.Fatalf("err=%v summary=%+v", err, final.Summary)
		}
	})
}

func TestR4BackendInvoiceDeletionReplacementBeforeCompletion(t *testing.T) {
	s, _ := testService(t)
	id := "wo_ready"
	mustAct(t, s, "dispatcher", id, "requirements", map[string]any{"documentRequirement": "none", "documentReason": "无需资料", "invoiceRequirement": "required", "invoiceReason": "约定票额", "invoiceDueCents": 50000})
	addPDF := func(name string) string {
		o := mustAct(t, s, "finance", id, "evidence", map[string]any{"name": name, "kind": "document", "mime": "application/pdf", "data": base64.StdEncoding.EncodeToString([]byte("%PDF-1.4\n% synthetic only\n%%EOF\n"))})
		return o.Evidence[len(o.Evidence)-1].ID
	}
	file := addPDF("合成旧票.pdf")
	o := mustAct(t, s, "finance", id, "invoice", map[string]any{"number": "R4-OLD", "amountCents": 50000, "files": []string{file}})
	invoiceID := o.Invoices[len(o.Invoices)-1].ID
	o = mustAct(t, s, "finance", id, "delete_evidence", map[string]any{"evidenceId": file, "reason": "合成旧票遗失"})
	t.Run("deleted_evidence_blocks_completion", func(t *testing.T) {
		if o.Status != "settling" || o.Summary.InvoiceStatus != "需补附件" {
			t.Fatal(o.Summary)
		}
		_, e := testAct(t, s, "dispatcher", id, "complete", map[string]any{})
		expectCode(t, e, "completion_blocked")
	})
	mustAct(t, s, "finance", id, "void_invoice", map[string]any{"invoiceId": invoiceID, "reason": "合成红冲更正"})
	replacement := addPDF("合成新票.pdf")
	o = mustAct(t, s, "finance", id, "invoice", map[string]any{"number": "R4-NEW", "amountCents": 50000, "files": []string{replacement}})
	t.Run("replacement_restores_exact_amount", func(t *testing.T) {
		if o.Status != "pending_completion" || o.Summary.InvoiceCents != 50000 {
			t.Fatal(o.Summary)
		}
	})
	done := mustAct(t, s, "dispatcher", id, "complete", map[string]any{"note": "合成真实核对"})
	t.Run("completion_preserves_deleted_tombstone", func(t *testing.T) {
		if done.Status != "completed" || done.Evidence[0].ID == "" {
			t.Fatal(done.Status)
		}
		original := testOrder(t, s, id)
		if !original.Evidence[0].Deleted || original.Evidence[0].Data != "" {
			t.Fatal("deleted source revived")
		}
	})
}

func TestR4BackendFailureCannotTriggerAutoAcceptance(t *testing.T) {
	s, _ := testService(t)
	clock := r4Time(t, "2026-01-24T12:00:00+08:00")
	o := r4Delivery(t, s, clock, 3, true)
	stopped := mustAct(t, s, "dispatcher", o.ID, "failure", map[string]any{"reason": "cancelled", "note": "合成协商取消，不伪造验收", "amountCents": 0, "returnRequired": true})
	if stopped.Outcome != "cancelled" {
		t.Fatal(stopped.Outcome)
	}
	s.now = func() time.Time { return clock.AddDate(0, 1, 0) }
	if err := s.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	final := testOrder(t, s, o.ID)
	t.Run("stale_acceptance_deadline_not_used", func(t *testing.T) {
		if final.AcceptedAt != "" || final.Warranty.StartsAt != "" || final.Outcome != "cancelled" {
			t.Fatal(final.Outcome, final.AcceptedAt, final.Warranty)
		}
	})
	t.Run("return_obligation_still_blocks", func(t *testing.T) {
		if final.Status != "settling" || !strings.Contains(strings.Join(final.Summary.Missing, ";"), "退件") {
			t.Fatal(final.Summary)
		}
	})
}

func TestR4BackendRejectedAcceptanceRetainsSubmittedSignature(t *testing.T) {
	s, p := testService(t)
	now := r4Time(t, "2026-10-15T10:00:00+08:00")
	o := r4Delivery(t, s, now, 3, true)
	img := image.NewRGBA(image.Rect(0, 0, 80, 40))
	for x := 5; x < 65; x++ {
		img.Set(x, 5+x%25, color.RGBA{R: 20, G: 40, B: 60, A: 255})
	}
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, img); err != nil {
		t.Fatal(err)
	}
	signature := "data:image/png;base64," + base64.StdEncoding.EncodeToString(encoded.Bytes())
	if err := validSignature(signature); err != nil {
		t.Fatal(err)
	}
	o = mustAct(t, s, "customer", o.ID, "accept", map[string]any{"passed": false, "signature": signature, "note": "独立合成：实测仍有故障，不通过验收"})
	t.Run("rejection_remains_pending_without_warranty", func(t *testing.T) {
		if o.Status != "pending_acceptance" || o.AcceptedAt != "" || o.Warranty.StartsAt != "" || len(o.Issues) != 1 {
			t.Fatal(o.Status, o.AcceptedAt, o.Warranty)
		}
	})
	t.Run("submitted_signature_is_durably_retained", func(t *testing.T) {
		if !bytes.Contains(p.data, []byte(signature)) {
			t.Fatal("accepted non-passing acceptance submission discarded its validated signature; snapshot contains only the textual issue/event")
		}
	})
	s2, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	s2.now = func() time.Time { return now.AddDate(0, 0, 10) }
	if err = s2.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	t.Run("restart_and_sweep_do_not_convert_rejection_to_acceptance", func(t *testing.T) {
		after := testOrder(t, s2, o.ID)
		if after.Outcome != "" || after.AcceptedAt != "" {
			t.Fatal("rejection was silently converted to acceptance")
		}
	})
}
