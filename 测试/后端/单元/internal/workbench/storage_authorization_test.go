package workbench

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestFileBackupRestoreKeepsCurrentOrderAuthorizationAndHistoricalSigner(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "current")
	keyFile := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}

	// Cache a real signed response so recovery also exercises revoked idempotent retries.
	unsigned := testOrder(t, s, "wo_quote")
	signPayload := map[string]any{"signature": syntheticSignature(), "quoteVersion": 1}
	signKey := "before-backup-signature"
	signed, err := testActVersion(s, testActor(s, "customer"), unsigned.ID, "sign_quote", signPayload, unsigned.Version, signKey)
	if err != nil {
		t.Fatal(err)
	}
	withFile := mustAct(t, s, "dispatcher", "wo_quote", "evidence", map[string]any{"name": "恢复授权合成证据.txt", "kind": "text", "text": "仅供恢复回归验证", "public": true})
	fileID := withFile.Evidence[len(withFile.Evidence)-1].ID
	backup := filepath.Join(dir, "independent", "before-handover.wbbak")
	if _, err = WriteBackup(p, keyFile, backup); err != nil {
		t.Fatal(err)
	}

	mustAct(t, s, "dispatcher", "wo_quote", "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成授权交接"})
	mustAct(t, s, "dispatcher", "wo_quote", "assign", map[string]any{"assigneeId": "outsource"})
	mustAct(t, s, "dispatcher", "wo_intake", "intake", map[string]any{"ownerId": "admin", "assigneeId": "outsource"})
	current := testOrder(t, s, "wo_quote")
	if visible(current, testActor(s, "customer")) || visible(current, testActor(s, "engineer")) {
		t.Fatal("test setup did not revoke original order access")
	}

	target := filepath.Join(dir, "restored")
	if err = RestoreBackup(backup, keyFile, dataDir, target); err != nil {
		t.Fatal(err)
	}
	rp, err := NewFilePersistence(target, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer rp.Close()
	restored, err := New(rp)
	if err != nil {
		t.Fatal(err)
	}
	order := testOrder(t, restored, "wo_quote")
	if order.CustomerID != "customer-peer" || order.CompanyID != "company-a" || order.AssigneeID != "outsource" || order.OwnerID != current.OwnerID {
		t.Fatal("restored order authorization differs from current source")
	}
	if !reflect.DeepEqual(order.Quote, signed.Quote) || order.Version != withFile.Version || order.Status != withFile.Status {
		t.Fatal("restoration changed historical signer or business snapshot")
	}
	intake := testOrder(t, restored, "wo_intake")
	if intake.OwnerID != "admin" || intake.AssigneeID != "outsource" || intake.Status != "pending_intake" {
		t.Fatal("current responsible people must be merged independently of historical intake state")
	}
	if !visible(testOrder(t, restored, "wo_ready"), testActor(restored, "customer")) {
		t.Fatal("per-order revocation removed an unrelated authorization")
	}

	handler := restored.Handler("")
	request := func(method, path, token string, body []byte, key string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, path, bytes.NewReader(body))
		r.Header.Set("Authorization", "Bearer "+token)
		if key != "" {
			r.Header.Set("Idempotency-Key", key)
		}
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	for _, actorID := range []string{"customer", "engineer", "customer-peer", "outsource"} {
		t.Run(actorID, func(t *testing.T) {
			token, _, err := restored.login(actorID, "Demo-Repair-2026!", "restore-test")
			if err != nil {
				t.Fatal(err)
			}
			allowed := actorID == "customer-peer" || actorID == "outsource"
			wantStatus := http.StatusNotFound
			if allowed {
				wantStatus = http.StatusOK
			}
			for _, path := range []string{"/api/v38/orders/wo_quote", "/api/v38/orders/wo_quote/evidence/" + fileID} {
				if got := request("GET", path, token, nil, ""); got.Code != wantStatus {
					t.Fatalf("%s status=%d want=%d", path, got.Code, wantStatus)
				}
			}
			for _, path := range []string{"/api/v38/orders", "/api/v38/bootstrap"} {
				w := request("GET", path, token, nil, "")
				if w.Code != http.StatusOK {
					t.Fatalf("%s status=%d", path, w.Code)
				}
				var response struct {
					Orders []Order `json:"orders"`
				}
				if path == "/api/v38/orders" {
					var list struct {
						Items []Order `json:"items"`
					}
					if err := json.Unmarshal(w.Body.Bytes(), &list); err != nil {
						t.Fatal(err)
					}
					response.Orders = list.Items
				} else if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
					t.Fatal(err)
				}
				found := false
				for _, o := range response.Orders {
					found = found || o.ID == "wo_quote"
				}
				if found != allowed {
					t.Fatalf("%s contains restored order=%v want=%v", path, found, allowed)
				}
			}
			if actorID == "customer" || actorID == "customer-peer" {
				w := request("GET", "/api/v38/export", token, nil, "")
				if w.Code != http.StatusOK {
					t.Fatalf("export status=%d", w.Code)
				}
				var exported struct {
					Orders []Order `json:"orders"`
				}
				if err := json.Unmarshal(w.Body.Bytes(), &exported); err != nil {
					t.Fatal(err)
				}
				found := false
				for _, o := range exported.Orders {
					found = found || o.ID == "wo_quote"
				}
				if found != allowed {
					t.Fatal("export restored a revoked order authorization")
				}
			}
			if actorID == "customer" {
				payload, _ := json.Marshal(signPayload)
				body, _ := json.Marshal(Action{Type: "sign_quote", Version: unsigned.Version, Payload: payload})
				if w := request("POST", "/api/v38/orders/wo_quote/actions", token, body, signKey); w.Code != http.StatusNotFound {
					t.Fatalf("cached original signer response exposed after recovery: status=%d", w.Code)
				}
			}
		})
	}
}

func TestRestoreRefusesMissingOrMalformedOrderConstraintsBeforeWritingTarget(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "current")
	keyFile := filepath.Join(dir, "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	baseline := testRecoveryJSON(t, `{"orders":[{"id":"wo_recovery","customerId":"customer","companyId":"company-a","assigneeId":"engineer","ownerId":"dispatcher","evidence":[{"id":"file_recovery","deleted":false,"text":"合成证据"}]}]}`, testRecoveryAccounts(t))
	if err := p.Save(baseline); err != nil {
		t.Fatal(err)
	}
	backup := filepath.Join(dir, "backup.wbbak")
	if _, err := WriteBackup(p, keyFile, backup); err != nil {
		t.Fatal(err)
	}
	type constraintCase struct {
		name   string
		mutate func(map[string]any, map[string]any)
	}
	cases := []constraintCase{
		{"orders_missing", func(s, o map[string]any) { delete(s, "orders") }},
		{"orders_not_array", func(s, o map[string]any) { s["orders"] = map[string]any{} }},
		{"stable_id_missing", func(s, o map[string]any) { delete(o, "id") }},
		{"stable_id_not_string", func(s, o map[string]any) { o["id"] = 7 }},
		{"stable_id_blank", func(s, o map[string]any) { o["id"] = " " }},
		{"order_not_object", func(s, o map[string]any) { s["orders"] = []any{false} }},
		{"old_order_missing_current_constraint", func(s, o map[string]any) { s["orders"] = []any{} }},
		{"duplicate_order_id", func(s, o map[string]any) { s["orders"] = []any{o, o} }},
		{"evidence_source_missing", func(s, o map[string]any) { delete(o, "evidence") }},
		{"evidence_source_incomplete", func(s, o map[string]any) { o["evidence"] = []any{} }},
		{"evidence_source_not_array", func(s, o map[string]any) { o["evidence"] = true }},
		{"deletion_marker_not_boolean", func(s, o map[string]any) { o["evidence"].([]any)[0].(map[string]any)["deleted"] = "false" }},
		{"deletion_marker_missing", func(s, o map[string]any) { delete(o["evidence"].([]any)[0].(map[string]any), "deleted") }},
		{"duplicate_evidence_id", func(s, o map[string]any) {
			e := o["evidence"].([]any)[0]
			o["evidence"] = []any{e, e}
		}},
		{"customer_id_blank", func(s, o map[string]any) { o["customerId"] = "" }},
		{"company_id_blank", func(s, o map[string]any) { o["companyId"] = " " }},
		{"accounts_not_array", func(s, o map[string]any) { s["accounts"] = nil }},
	}
	for _, field := range []string{"customerId", "companyId", "assigneeId", "ownerId"} {
		cases = append(cases,
			constraintCase{field + "_missing", func(s, o map[string]any) { delete(o, field) }},
			constraintCase{field + "_not_string", func(s, o map[string]any) { o[field] = false }},
		)
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var state map[string]any
			if err := json.Unmarshal(baseline, &state); err != nil {
				t.Fatal(err)
			}
			order := state["orders"].([]any)[0].(map[string]any)
			tc.mutate(state, order)
			raw, err := json.Marshal(state)
			if err != nil {
				t.Fatal(err)
			}
			if err = p.Save(raw); err != nil {
				t.Fatal(err)
			}
			target := filepath.Join(dir, "rejected-"+tc.name)
			if err := RestoreBackup(backup, keyFile, dataDir, target); err == nil {
				t.Fatal("incomplete authorization source accepted")
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("rejected recovery left an exposable target")
			}
		})
	}
}

func TestMergeRestrictionsUsesCurrentCompanyAndExplicitUnassignedPeople(t *testing.T) {
	accounts := testRecoveryAccounts(t)
	backup := testRecoveryJSON(t, `{"orders":[{"id":"wo_recovery","customerId":"customer","companyId":"company-a","assigneeId":"engineer","ownerId":"dispatcher","evidence":[],"quote":{"signed":true,"signer":"原历史签署人"},"status":"repairing","version":7}]}`, accounts)
	latest := testRecoveryJSON(t, `{"orders":[{"id":"wo_recovery","customerId":"customer-b","companyId":"company-b","assigneeId":"","ownerId":"","evidence":[],"quote":{"signed":false},"status":"settling","version":9}]}`, accounts)
	merged, err := mergeRestrictions(backup, latest)
	if err != nil {
		t.Fatal(err)
	}
	var state State
	if err := json.Unmarshal(merged, &state); err != nil {
		t.Fatal(err)
	}
	o := state.Orders[0]
	if o.CustomerID != "customer-b" || o.CompanyID != "company-b" || o.AssigneeID != "" || o.OwnerID != "" {
		t.Fatal("current authorization fields were not applied exactly")
	}
	if !o.Quote.Signed || o.Quote.Signer != "原历史签署人" || o.Status != "repairing" || o.Version != 7 {
		t.Fatal("authorization merge overwrote historical business facts")
	}
}
