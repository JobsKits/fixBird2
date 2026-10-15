package workbench

import (
	"bytes"
	"encoding/json"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"
)

var r5SeedOnce sync.Once
var r5Seed []byte
var r5SeedError error
var r5Tokens = map[*Service]map[string]struct {
	token  string
	expiry time.Time
}{}

func r5Service(t *testing.T) (*Service, *testPersistence) {
	t.Helper()
	r5SeedOnce.Do(func() {
		p := &testPersistence{}
		_, r5SeedError = New(p)
		r5Seed = append([]byte(nil), p.data...)
	})
	if r5SeedError != nil {
		t.Fatal(r5SeedError)
	}
	p := &testPersistence{data: append([]byte(nil), r5Seed...)}
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return s, p
}

func r5Token(t *testing.T, s *Service, actor string) string {
	t.Helper()
	if r5Tokens[s] == nil {
		r5Tokens[s] = map[string]struct {
			token  string
			expiry time.Time
		}{}
	}
	entry := r5Tokens[s][actor]
	if entry.token != "" && s.now().Before(entry.expiry) {
		return entry.token
	}
	token := secondPermissionToken(t, s, actor)
	r5Tokens[s][actor] = struct {
		token  string
		expiry time.Time
	}{token: token, expiry: s.now().Add(11 * time.Hour)}
	return token
}

func r5HTTP(t *testing.T, s *Service, actor, method, path string, input any) (int, []byte) {
	t.Helper()
	token := r5Token(t, s, actor)
	var raw []byte
	if input != nil {
		var err error
		raw, err = json.Marshal(input)
		if err != nil {
			t.Fatal(err)
		}
	}
	w := secondPermissionHTTP(s, token, method, path, randomID("r5_"), raw)
	return w.Code, w.Body.Bytes()
}

func r5ActHTTP(t *testing.T, s *Service, actor, id, action string, payload any) (int, []byte) {
	t.Helper()
	o := testOrder(t, s, id)
	return r5HTTP(t, s, actor, http.MethodPost, "/api/v38/orders/"+id+"/actions", map[string]any{"type": action, "version": o.Version, "payload": payload})
}

func r5MustActHTTP(t *testing.T, s *Service, actor, id, action string, payload any) Order {
	t.Helper()
	status, raw := r5ActHTTP(t, s, actor, id, action, payload)
	if status != http.StatusOK {
		t.Fatalf("%s/%s status=%d body=%s", actor, action, status, raw)
	}
	return acceptanceResponse(t, raw)
}

func TestR5BackendReworkReferenceGuards(t *testing.T) {
	for _, tc := range []struct {
		name, actor, parent string
		reject              bool
	}{
		{"ordinary_no_reference", "customer", "", false},
		{"missing_parent", "customer", "wo_missing_r5", true},
		{"foreign_company_parent", "customer-b", "wo_ready", true},
		{"own_unaccepted_parent", "customer", "wo_quote", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := r5Service(t)
			before := len(s.state.Orders)
			status, raw := r5HTTP(t, s, tc.actor, http.MethodPost, "/api/v38/orders", map[string]any{"type": "mail", "customer": "第五轮合成客户", "device": "第五轮合成设备", "description": "复核返修来源关系", "originalOrderId": tc.parent})
			t.Logf("actor=%s parent=%q status=%d persistedCount=%d before=%d", tc.actor, tc.parent, status, len(s.state.Orders), before)
			if tc.reject {
				if status < 400 || len(s.state.Orders) != before {
					t.Fatalf("invalid or unauthorized rework link committed: status=%d body=%s", status, raw)
				}
			} else if status != http.StatusCreated {
				t.Fatalf("ordinary creation failed: %d %s", status, raw)
			}
		})
	}
	t.Run("foreign_parent_itself_remains_unreadable", func(t *testing.T) {
		s, _ := r5Service(t)
		status, raw := r5HTTP(t, s, "customer-b", http.MethodGet, "/api/v38/orders/wo_ready", nil)
		if status != http.StatusNotFound && status != http.StatusForbidden {
			t.Fatalf("foreign detail readable: %d %s", status, raw)
		}
	})
	t.Run("direct_rework_requires_acceptance", func(t *testing.T) {
		s, _ := r5Service(t)
		status, raw := r5ActHTTP(t, s, "dispatcher", "wo_quote", "rework", map[string]any{"free": true, "note": "第五轮未验收返修"})
		if status != http.StatusUnprocessableEntity || !bytes.Contains(raw, []byte("acceptance_required")) {
			t.Fatalf("unaccepted rework guard changed: %d %s", status, raw)
		}
	})
	t.Run("direct_rework_requires_company_role", func(t *testing.T) {
		s, _ := r5Service(t)
		status, raw := r5ActHTTP(t, s, "customer", "wo_ready", "rework", map[string]any{"free": true, "note": "第五轮客户直接返修"})
		if status != http.StatusForbidden {
			t.Fatalf("role guard changed: %d %s", status, raw)
		}
	})
}

func r5ReworkQuote(t *testing.T, s *Service, free bool, amount int64) (int, []byte, Order) {
	t.Helper()
	child := r5MustActHTTP(t, s, "dispatcher", "wo_ready", "rework", map[string]any{"free": free, "note": "合成质保问题，业务已核实本次处理范围"})
	r5MustActHTTP(t, s, "dispatcher", child.ID, "intake", map[string]any{"ownerId": "dispatcher", "assigneeId": "engineer"})
	r5MustActHTTP(t, s, "engineer", child.ID, "diagnose", map[string]any{"note": "合成返修故障已定位"})
	status, raw := r5ActHTTP(t, s, "engineer", child.ID, "quote", map[string]any{"amountCents": amount, "description": "合成返修方案，原范围内更换及测试", "warrantyMonths": 3, "paymentTerms": "credit", "prepayCents": 0, "startRequiresPrepayment": false, "validUntil": nowString(s.now().Add(time.Hour)), "autoAccept": true})
	return status, raw, child
}

func TestR5BackendFreeReworkQuote(t *testing.T) {
	for _, tc := range []struct {
		name   string
		free   bool
		amount int64
		want   int
	}{
		{"free_zero_quote_must_be_possible", true, 0, http.StatusOK},
		{"charged_positive_quote", false, 10000, http.StatusOK},
		{"negative_quote_rejected", true, -1, http.StatusUnprocessableEntity},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := r5Service(t)
			parent := testOrder(t, s, "wo_ready")
			status, raw, child := r5ReworkQuote(t, s, tc.free, tc.amount)
			t.Logf("free=%v amount=%d child=%s status=%d original=%s reason=%q", tc.free, tc.amount, child.ID, status, child.OriginalOrderID, child.Remark)
			if testOrder(t, s, "wo_ready").Version != parent.Version {
				t.Fatal("child operation mutated original version")
			}
			if status != tc.want {
				t.Fatalf("quote status=%d want=%d body=%s", status, tc.want, raw)
			}
		})
	}
}

func TestR5BackendIssueResolutionMustNotSilentlyRestartExpiredAcceptance(t *testing.T) {
	for _, tc := range []struct {
		name   string
		reject bool
	}{
		{"customer_issue", false}, {"signed_rejection", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := r5Service(t)
			now := s.now()
			delivery := r4Delivery(t, s, now, 3, true)
			var issue Order
			if tc.reject {
				issue = r5MustActHTTP(t, s, "customer", delivery.ID, "accept", map[string]any{"passed": false, "signature": syntheticSignature(), "note": "第五轮合成客户拒绝验收，要求整改后重新核验"})
			} else {
				issue = r5MustActHTTP(t, s, "customer", delivery.ID, "issue", map[string]any{"note": "第五轮合成客户要求整改后重新核验", "ownerId": "dispatcher", "dueAt": nowString(now.Add(48 * time.Hour))})
			}
			later := now.Add(10 * 24 * time.Hour)
			s.now = func() time.Time { return later }
			status, raw := r5HTTP(t, s, "dispatcher", http.MethodPost, "/api/v38/auto-accept", map[string]any{})
			if status != http.StatusOK || testOrder(t, s, delivery.ID).AcceptedAt != "" {
				t.Fatalf("unresolved issue did not block scan: %d %s", status, raw)
			}
			r5MustActHTTP(t, s, "dispatcher", delivery.ID, "resolve_issue", map[string]any{"issueId": issue.Issues[len(issue.Issues)-1].ID, "note": "工程整改已完成，等待客户复验；尚未确认恢复验收窗口"})
			status, raw = r5HTTP(t, s, "dispatcher", http.MethodPost, "/api/v38/auto-accept", map[string]any{})
			after := testOrder(t, s, delivery.ID)
			t.Logf("scanStatus=%d result=%s due=%s accepted=%s signed=%s history=%d", status, raw, delivery.AcceptanceDueAt, after.AcceptedAt, after.Quote.SignedAt, len(after.AcceptanceRecords))
			if status != http.StatusOK {
				t.Fatalf("scan request failed: %d %s", status, raw)
			}
			if after.AcceptedAt != "" {
				t.Fatalf("resolving issue silently resumed expired window, accepted retroactively at %s without customer-confirmed resume or new delivery", after.AcceptedAt)
			}
		})
	}
}

func TestR5BackendAcceptanceHistoryVersionAndAuthorizationControls(t *testing.T) {
	t.Run("stale_order_version_does_not_append", func(t *testing.T) {
		s, _ := r5Service(t)
		now := s.now()
		delivered := r4Delivery(t, s, now, 3, false)
		token := secondPermissionToken(t, s, "customer")
		body := acceptanceActionBody(t, delivered.Version-1, false, syntheticSignature(), "合成旧版本拒绝")
		w := secondPermissionHTTP(s, token, http.MethodPost, "/api/v38/orders/"+delivered.ID+"/actions", "r5-stale", body)
		if w.Code != http.StatusConflict || len(testOrder(t, s, delivered.ID).AcceptanceRecords) != 0 {
			t.Fatalf("stale appended: %d %s", w.Code, w.Body.String())
		}
	})
	t.Run("new_contact_can_reject_without_rewriting_old_signature", func(t *testing.T) {
		s, _ := r5Service(t)
		now := s.now()
		delivered := r4Delivery(t, s, now, 3, false)
		first := r5MustActHTTP(t, s, "customer", delivered.ID, "accept", map[string]any{"passed": false, "signature": syntheticSignature(), "note": "合成原经办人异议"})
		original := first.AcceptanceRecords[0]
		r5MustActHTTP(t, s, "dispatcher", delivered.ID, "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成经办交接"})
		second := r5MustActHTTP(t, s, "customer-peer", delivered.ID, "accept", map[string]any{"passed": false, "signature": syntheticSignature(), "note": "合成新经办人追加异议"})
		if len(second.AcceptanceRecords) != 2 || second.AcceptanceRecords[0] != original || second.AcceptanceRecords[1].SignerID != "customer-peer" {
			t.Fatal("history changed after contact handover")
		}
	})
	t.Run("old_contact_retry_does_not_leak_historical_signature", func(t *testing.T) {
		s, _ := r5Service(t)
		now := s.now()
		delivered := r4Delivery(t, s, now, 3, false)
		token := secondPermissionToken(t, s, "customer")
		body := acceptanceActionBody(t, delivered.Version, false, syntheticSignature(), "合成原经办人异议")
		path := "/api/v38/orders/" + delivered.ID + "/actions"
		w := secondPermissionHTTP(s, token, http.MethodPost, path, "r5-history-replay", body)
		if w.Code != http.StatusOK {
			t.Fatal(w.Code, w.Body.String())
		}
		r5MustActHTTP(t, s, "dispatcher", delivered.ID, "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成交接后重试"})
		w = secondPermissionHTTP(s, token, http.MethodPost, path, "r5-history-replay", body)
		if w.Code != http.StatusNotFound && w.Code != http.StatusForbidden {
			t.Fatalf("revoked replay status %d", w.Code)
		}
		if strings.Contains(w.Body.String(), syntheticSignature()) {
			t.Fatal("revoked replay leaks original")
		}
	})
}

func TestR5BackendBackdatedDeliveryCannotPrecedeConfirmedQuote(t *testing.T) {
	s, _ := r5Service(t)
	now := s.now()
	id := "wo_quote"
	r5MustActHTTP(t, s, "customer", id, "sign_quote", map[string]any{"signature": syntheticSignature(), "quoteVersion": 1})
	r5MustActHTTP(t, s, "engineer", id, "start", map[string]any{"note": "实际开始"})
	r5MustActHTTP(t, s, "engineer", id, "finish", map[string]any{"note": "实际完成"})
	r5MustActHTTP(t, s, "qc", id, "qc", map[string]any{"passed": true, "note": "实际质检完成"})
	status, raw := r5ActHTTP(t, s, "warehouse", id, "deliver", map[string]any{"note": "合成误录实收日期，早于创建与客户确认", "deliveredAt": nowString(now.AddDate(-2, 0, 0))})
	t.Logf("deliveryStatus=%d body=%s", status, raw)
	if status == http.StatusOK {
		status2, result := r5HTTP(t, s, "dispatcher", http.MethodPost, "/api/v38/auto-accept", map[string]any{})
		after := testOrder(t, s, id)
		t.Logf("scanStatus=%d result=%s accepted=%s quoteSignedAt=%s createdAt=%s warranty=%+v", status2, result, after.AcceptedAt, after.Quote.SignedAt, after.CreatedAt, after.Warranty)
	}
	if status < 400 {
		t.Fatal("impossible delivery preceding current quote and creation was committed")
	}
}
