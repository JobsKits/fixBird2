package workbench

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestLoanCreatedAtPersistsAcrossRetryActionsAndLists(t *testing.T) {
	s, persistence := testService(t)
	now := time.Date(2026, 11, 18, 10, 30, 0, 0, time.FixedZone("CST", 8*60*60))
	s.now = func() time.Time { return now }
	want := nowString(now)
	input := LoanInput{OrderID: "wo_intake", PartID: "part-board", Quantity: 2, BorrowerID: "engineer", DueAt: "2027-01-01T23:59:59+08:00", Note: "合成借出交接事实"}
	created := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "loan-created-time", input), 201)
	if created.CreatedAt != want || testOrder(t, s, input.OrderID).UpdatedAt != want {
		t.Fatalf("actual borrow time missing or inconsistent: %+v", created)
	}
	now = now.Add(time.Hour)
	replayed := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "loan-created-time", input), 201)
	if replayed.CreatedAt != want {
		t.Fatal("retry replaced the actual borrow time with the read time")
	}
	payload, _ := json.Marshal(loanPayload{Quantity: 1, Condition: "good", Reason: "合成归还依据", Note: "合成归还交接事实"})
	returned := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/actions", "warehouse", "loan-return-after-time", Action{Type: "return", Version: created.Version, Payload: payload}), 200)
	if returned.CreatedAt != want {
		t.Fatal("return changed the borrow creation time")
	}
	restarted, err := New(persistence)
	if err != nil {
		t.Fatal(err)
	}
	for _, endpoint := range []string{"/bootstrap", "/parts/part-board"} {
		response := loanHTTPFixture(t, restarted, "GET", endpoint, "warehouse", "", nil)
		var out struct {
			Loans []Loan `json:"loans"`
		}
		if response.Code != 200 || json.Unmarshal(response.Body.Bytes(), &out) != nil || len(out.Loans) != 1 || out.Loans[0].CreatedAt != want {
			t.Fatalf("borrow timestamp lost in %s after restart: %d %s", endpoint, response.Code, response.Body.String())
		}
	}
	spoofed, _ := json.Marshal(input)
	var spoof map[string]any
	_ = json.Unmarshal(spoofed, &spoof)
	spoof["createdAt"] = "2000-01-01T00:00:00Z"
	if response := loanHTTPFixture(t, restarted, "POST", "/loans", "warehouse", "loan-spoofed-time", spoof); response.Code != 422 {
		t.Fatal("client was allowed to fabricate borrow creation time", response.Code)
	}
}

func TestLegacyLoanMissingCreatedAtStaysUnknownAfterReadAndRestart(t *testing.T) {
	s, persistence := testService(t)
	created, err := s.createLoan(&s.state, testActor(s, "warehouse"), LoanInput{PartID: "part-board", Quantity: 1, BorrowerID: "engineer", DueAt: "2027-01-01T23:59:59+08:00", Note: "旧版合成借出记录"})
	if err != nil {
		t.Fatal(err)
	}
	s.state.Loans[0].CreatedAt = ""
	raw, _ := json.Marshal(s.state)
	if err := persistence.Save(raw); err != nil {
		t.Fatal(err)
	}
	restarted, err := New(persistence)
	if err != nil {
		t.Fatal(err)
	}
	response := loanHTTPFixture(t, restarted, "GET", "/parts/part-board", "warehouse", "", nil)
	var out struct {
		Loans []Loan `json:"loans"`
	}
	if response.Code != 200 || json.Unmarshal(response.Body.Bytes(), &out) != nil || len(out.Loans) != 1 || out.Loans[0].ID != created.ID || out.Loans[0].CreatedAt != "" {
		t.Fatalf("legacy missing time was fabricated: %s", response.Body.String())
	}
	loanJSON, _ := json.Marshal(out.Loans[0])
	if strings.Contains(string(loanJSON), "createdAt") || restarted.state.Loans[0].CreatedAt != "" {
		t.Fatal("unknown legacy borrow time was backfilled")
	}
}
