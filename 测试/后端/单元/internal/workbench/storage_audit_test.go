package workbench

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestRecoveryKeepsAuditBeforeAndAfterBackupAndRecordsRestore(t *testing.T) {
	old := AuditEvent{ID: "audit_original", ActorID: "admin", ActorRole: "admin", Type: "account_status", Resource: "customer", Result: "success", At: "2026-10-14T01:00:00Z", Reason: "备份前合成授权依据", Before: "disabled", After: "active", AuthBefore: 1, AuthAfter: 2}
	latestOriginal := old
	latestOriginal.Reason = "当前来源的同一审计依据"
	revoked := AuditEvent{ID: "audit_revoked", ActorID: "admin", ActorRole: "admin", Type: "account_status", Resource: "customer", Result: "success", At: "2026-10-14T02:00:00Z", Reason: "备份后经办人离职，合成撤权依据", Before: "active", After: "disabled", AuthBefore: 2, AuthAfter: 3}
	accounts := testRecoveryAccounts(t)
	raw := func(events []AuditEvent) []byte {
		data, err := json.Marshal(map[string]any{"accounts": accounts, "orders": []any{}, "audit": events, "idempotency": map[string]CachedRequest{}})
		if err != nil {
			t.Fatal(err)
		}
		return data
	}
	merged, err := mergeRestrictions(raw([]AuditEvent{old}), raw([]AuditEvent{latestOriginal, revoked}))
	if err != nil {
		t.Fatal(err)
	}
	var state State
	if err := json.Unmarshal(merged, &state); err != nil {
		t.Fatal(err)
	}
	if len(state.Audit) != 3 || state.Audit[0].Reason != latestOriginal.Reason || !reflect.DeepEqual(state.Audit[1], revoked) {
		t.Fatal("restoration dropped or duplicated current revocation audit")
	}
	restored := state.Audit[2]
	if restored.ID == "" || restored.Type != "backup_restore" || restored.ActorID != "system:restore" || restored.Resource != "workbench" || restored.Result != "restored" {
		t.Fatal("restoration did not add a stable recovery audit")
	}
	legacy := testRecoveryJSON(t, `{"orders":[]}`, accounts)
	merged, err = mergeRestrictions(raw([]AuditEvent{old}), legacy)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(merged, &state); err != nil {
		t.Fatal(err)
	}
	if len(state.Audit) != 2 || !reflect.DeepEqual(state.Audit[0], old) {
		t.Fatal("legacy source without audit discarded backup audit")
	}
}

func TestRecoveryRejectsMalformedAudit(t *testing.T) {
	accounts := testRecoveryAccounts(t)
	backup := testRecoveryJSON(t, `{"orders":[]}`, accounts)
	valid := map[string]any{"id": "audit_valid", "actorId": "admin", "actorRole": "admin", "type": "account_status", "resource": "customer", "result": "success", "at": "2026-10-14T02:00:00Z"}
	cases := []struct {
		name  string
		audit any
	}{
		{"null", nil},
		{"not_array", map[string]any{}},
		{"not_record", []any{true}},
		{"id_only", []any{map[string]any{"id": "audit_missing_fields"}}},
		{"duplicate_id", []any{valid, valid}},
	}
	for field, value := range map[string]any{"id": 42, "at": "not-a-time", "reason": false, "authAfter": 1.5, "resourceIds": true} {
		event := map[string]any{}
		for k, v := range valid {
			event[k] = v
		}
		event[field] = value
		cases = append(cases, struct {
			name  string
			audit any
		}{field + "_malformed", []any{event}})
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			current, err := json.Marshal(map[string]any{"accounts": accounts, "orders": []any{}, "audit": tc.audit, "idempotency": map[string]CachedRequest{}})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := mergeRestrictions(backup, current); err == nil {
				t.Fatal("malformed current audit accepted during recovery")
			}
		})
	}
}

func TestFileRestoreKeepsFailedLoginAndAnonymousDenialAudit(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "current")
	keyFile := filepath.Join(dir, "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	handler := s.Handler("")
	login := httptest.NewRequest("POST", "/api/v38/login", strings.NewReader(`{"username":"admin","password":"wrong-synthetic-only"}`))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, login)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("failed login status=%d", w.Code)
	}
	backup := filepath.Join(dir, "backup.wbbak")
	if _, err := WriteBackup(p, keyFile, backup); err != nil {
		t.Fatal(err)
	}
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, httptest.NewRequest("GET", "/api/v38/orders", nil))
	if w.Code != http.StatusUnauthorized || len(s.state.Audit) != 2 {
		t.Fatal("anonymous denial did not add a separate audit")
	}
	for _, legacy := range []bool{false, true} {
		name := "current"
		if legacy {
			name = "legacy-anonymous"
			for i := range s.state.Audit {
				s.state.Audit[i].ActorID, s.state.Audit[i].ActorRole = "", ""
			}
			raw, err := json.Marshal(s.state)
			if err != nil {
				t.Fatal(err)
			}
			if err := p.Save(raw); err != nil {
				t.Fatal(err)
			}
		}
		t.Run(name, func(t *testing.T) {
			target := filepath.Join(dir, "restore-"+name)
			if err := RestoreBackup(backup, keyFile, dataDir, target); err != nil {
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
			if len(restored.state.Audit) != 3 {
				t.Fatal("recovery duplicated or dropped anonymous audit")
			}
			for _, event := range restored.state.Audit[:2] {
				if event.ActorID != "anonymous" || event.ActorRole != "anonymous" || event.Result != "denied" {
					t.Fatal("anonymous denial identity was not retained safely")
				}
			}
		})
	}
}
