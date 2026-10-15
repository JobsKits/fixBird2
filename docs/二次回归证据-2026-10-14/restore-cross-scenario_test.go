package workbench

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type restoreFixture struct {
	s                    *Service
	p                    *FilePersistence
	root, data, key, bak string
}

func newRestoreFixture(t *testing.T) restoreFixture {
	t.Helper()
	root := t.TempDir()
	data, key := filepath.Join(root, "source"), filepath.Join(root, "key.bin")
	p, err := NewFilePersistence(data, key)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Close() })
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return restoreFixture{s: s, p: p, root: root, data: data, key: key, bak: filepath.Join(root, "old.wbbak")}
}

func (f restoreFixture) backup(t *testing.T) {
	t.Helper()
	if _, err := WriteBackup(f.p, f.key, f.bak); err != nil {
		t.Fatal(err)
	}
}

func (f restoreFixture) restore(t *testing.T, suffix string) *Service {
	t.Helper()
	target := filepath.Join(f.root, "restore-"+suffix)
	if err := RestoreBackup(f.bak, f.key, f.data, target); err != nil {
		t.Fatal(err)
	}
	p, err := NewFilePersistence(target, f.key)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Close() })
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestRestoreSecondPostBackupAuthorizationKeysRemainConsumed(t *testing.T) {
	t.Run("account_disable_then_reenable", func(t *testing.T) {
		f := newRestoreFixture(t)
		f.backup(t)
		path := "/api/v38/accounts/customer/status"
		disable := `{"status":"disabled","reason":"合成离职撤权"}`
		if w := fixRequest(t, f.s, "admin", "POST", path, disable, "disable-after-backup"); w.Code != 200 {
			t.Fatal(w.Code)
		}
		if w := fixRequest(t, f.s, "admin", "POST", path, `{"status":"active","reason":"合成重新授权"}`, "reenable-after-backup"); w.Code != 200 {
			t.Fatal(w.Code)
		}
		current := testActor(f.s, "customer")
		restored := f.restore(t, "account")
		beforeAudit := len(restored.state.Audit)
		if got := testActor(restored, "customer"); got.Status != current.Status || got.AuthVersion != current.AuthVersion {
			t.Fatal("latest access state was not merged")
		}
		w := fixRequest(t, restored, "admin", "POST", path, disable, "disable-after-backup")
		got := testActor(restored, "customer")
		t.Logf("source account=%s/%d, before keys=%d, retry HTTP=%d, after account=%s/%d, audit=%d->%d", current.Status, current.AuthVersion, len(f.s.state.Requests), w.Code, got.Status, got.AuthVersion, beforeAudit, len(restored.state.Audit))
		if w.Code != 200 || got.Status != current.Status || got.AuthVersion != current.AuthVersion || len(restored.state.Audit) != beforeAudit {
			t.Fatal("old processed authorization request executed again after recovery")
		}
	})
	t.Run("contact_handover_then_handover_back", func(t *testing.T) {
		f := newRestoreFixture(t)
		original := testOrder(t, f.s, "wo_quote")
		f.backup(t)
		payload := map[string]any{"customerId": "customer-peer", "reason": "合成第一次交接"}
		if _, err := testActVersion(f.s, testActor(f.s, "dispatcher"), original.ID, "handover_contact", payload, original.Version, "handover-after-backup"); err != nil {
			t.Fatal(err)
		}
		mustAct(t, f.s, "dispatcher", original.ID, "handover_contact", map[string]any{"customerId": "customer", "reason": "合成重新交回"})
		restored := f.restore(t, "contact")
		before := testOrder(t, restored, original.ID)
		_, err := testActVersion(restored, testActor(restored, "dispatcher"), original.ID, "handover_contact", payload, original.Version, "handover-after-backup")
		after := testOrder(t, restored, original.ID)
		t.Logf("restored contact=%s v%d, retry error=%v, after contact=%s v%d", before.CustomerID, before.Version, err, after.CustomerID, after.Version)
		if err != nil || after.CustomerID != before.CustomerID || after.Version != before.Version {
			t.Fatal("old processed handover displaced the latest restored contact")
		}
	})
}

func TestRestoreSecondMutationRetryCannotReadNewPrivateDataWhenAuditFails(t *testing.T) {
	s, p := testService(t)
	initial := testOrder(t, s, "wo_quote")
	payload := map[string]any{"remark": "合成初始操作"}
	initialBody, _ := json.Marshal(map[string]any{"type":"remark","version":initial.Version,"payload":payload})
	if first := fixRequest(t, s, "admin", "POST", "/api/v38/orders/wo_quote/actions", string(initialBody), "private-read-retry"); first.Code != 200 {
		t.Fatal(first.Code)
	}
	mustAct(t, s, "finance", initial.ID, "cost", map[string]any{"amountCents": 1000, "category": "合成成本", "note": "RESTORE-PRIVATE-FINANCIAL-SENTINEL"})
	token, _, err := s.login("admin", "Demo-Repair-2026!", "audit-fail-second-review")
	if err != nil {
		t.Fatal(err)
	}
	p.fail = true
	r := httptest.NewRequest("POST", "/api/v38/orders/wo_quote/actions", bytes.NewReader(initialBody))
	r.Header.Set("Authorization", "Bearer "+token)
	r.Header.Set("Idempotency-Key", "private-read-retry")
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	leaked := bytes.Contains(w.Body.Bytes(), []byte("RESTORE-PRIVATE-FINANCIAL-SENTINEL"))
	t.Logf("private data was added after original response; failing audit store: retry HTTP=%d, new private data returned=%v", w.Code, leaked)
	if w.Code < 400 || leaked {
		t.Fatal("reconstructed current private view bypassed audit failure")
	}
}

func TestRestoreSecondMalformedCurrentAccountCannotAuthorizeWrites(t *testing.T) {
	f := newRestoreFixture(t)
	f.backup(t)
	for i := range f.s.state.Accounts {
		if f.s.state.Accounts[i].Actor.ID == "admin" {
			f.s.state.Accounts[i].Actor.Status = ""
		}
	}
	raw, err := json.Marshal(f.s.state)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.p.Save(raw); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(f.root, "restore-invalid-account")
	err = RestoreBackup(f.bak, f.key, f.data, target)
	if err != nil {
		return
	}
	p, err := NewFilePersistence(target, f.key)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	s, err := New(p)
	if err != nil {
		return
	}
	w := fixRequest(t, s, "admin", "POST", "/api/v38/accounts/customer/status", `{"status":"disabled","reason":"坏授权来源不应允许此操作"}`, "invalid-actor-write")
	t.Logf("valid encrypted latest source has admin status empty; restore accepted, startup accepted, write HTTP=%d, customer=%s", w.Code, testActor(s, "customer").Status)
	if w.Code < 400 {
		t.Fatal("malformed access source authorized an administrator mutation")
	}
}

func TestRestoreSecondBackupKeysAndRollbackFactsStayCoherent(t *testing.T) {
	f := newRestoreFixture(t)
	path := "/api/v38/accounts/customer/status"
	disable := `{"status":"disabled","reason":"合成备份前撤权"}`
	if w := fixRequest(t, f.s, "admin", "POST", path, disable, "disable-before-backup"); w.Code != 200 {
		t.Fatal(w.Code)
	}
	actor := testActor(f.s, "warehouse")
	input := LoanInput{PartID: "part-board", Quantity: 2, BorrowerID: "engineer", DueAt: nowString(time.Now().Add(time.Hour)), Note: "合成备份前借出"}
	raw, _ := json.Marshal(input)
	borrowBody, _, err := f.s.transact(actor, "POST /api/v38/loans", "borrow-before-backup", raw, 201, func(st *State) (any, error) { return f.s.createLoan(st, actor, input) })
	if err != nil {
		t.Fatal(err)
	}
	var loan Loan
	if err := json.Unmarshal(borrowBody, &loan); err != nil {
		t.Fatal(err)
	}
	f.backup(t)
	if w := fixRequest(t, f.s, "admin", "POST", path, `{"status":"active","reason":"合成备份后新授权"}`, "enable-later"); w.Code != 200 {
		t.Fatal(w.Code)
	}
	payload, _ := json.Marshal(loanPayload{Quantity: 1, Condition: "good"})
	action := Action{Type: "return", Version: loan.Version, Payload: payload}
	returnRaw, _ := json.Marshal(action)
	returnPath := "POST /api/v38/loans/" + loan.ID + "/actions"
	if _, _, err := f.s.transact(actor, returnPath, "return-after-backup", returnRaw, 200, func(st *State) (any, error) { return f.s.loanAction(st, actor, loan.ID, action) }); err != nil {
		t.Fatal(err)
	}
	restored := f.restore(t, "coherent")
	latestAuth := testActor(restored, "customer")
	if w := fixRequest(t, restored, "admin", "POST", path, disable, "disable-before-backup"); w.Code != 200 || testActor(restored, "customer") != latestAuth {
		t.Fatal("backup-retained access key changed latest account")
	}
	beforeStock := restored.state.Parts[0].Available
	if _, _, err := restored.transact(testActor(restored, "warehouse"), "POST /api/v38/loans", "borrow-before-backup", raw, 201, func(st *State) (any, error) { t.Fatal("retained borrow key executed"); return nil, nil }); err != nil {
		t.Fatal(err)
	}
	if restored.state.Parts[0].Available != beforeStock || restored.state.Loans[0].Outstanding != 2 {
		t.Fatal("retained key duplicated inventory")
	}
	// This post-backup business fact was rolled back; unlike current access facts,
	// its request key is also absent. Reapplying the confirmed fact restores the ledger once.
	if _, _, err := restored.transact(testActor(restored, "warehouse"), returnPath, "return-after-backup", returnRaw, 200, func(st *State) (any, error) {
		return restored.loanAction(st, testActor(restored, "warehouse"), loan.ID, action)
	}); err != nil {
		t.Fatal(err)
	}
	if restored.state.Parts[0].Available != beforeStock+1 || restored.state.Loans[0].Outstanding != 1 {
		t.Fatal("rolled-back return fact was swallowed or doubled")
	}
	t.Log("retained pre-backup keys deduplicate; post-backup inventory fact and its key both roll back consistently")
}

func TestRestoreSecondCorruptionRefusedBeforeExposure(t *testing.T) {
	for _, kind := range []string{"backup_digest", "source_truncated", "missing_key", "bad_order_auth", "missing_audit_identity", "bad_idempotency_reference"} {
		t.Run(kind, func(t *testing.T) {
			f := newRestoreFixture(t)
			f.backup(t)
			switch kind {
			case "backup_digest":
				data, _ := os.ReadFile(f.bak)
				data[len(data)/2] ^= 1
				if err := os.WriteFile(f.bak, data, 0600); err != nil {
					t.Fatal(err)
				}
			case "source_truncated":
				if err := os.WriteFile(filepath.Join(f.data, "snapshot.enc"), []byte(`{"format":`), 0600); err != nil {
					t.Fatal(err)
				}
			case "missing_key":
				if err := os.Remove(f.key); err != nil {
					t.Fatal(err)
				}
			case "bad_order_auth":
				raw, _ := f.p.Load()
				var state map[string]any
				_ = json.Unmarshal(raw, &state)
				state["orders"].([]any)[0].(map[string]any)["customerId"] = false
				data, _ := json.Marshal(state)
				if err := f.p.Save(data); err != nil {
					t.Fatal(err)
				}
			case "missing_audit_identity":
				f.s.state.Audit = append(f.s.state.Audit, AuditEvent{ID: "audit_corrupt", Type: "account_status", Resource: "customer", Result: "success", At: nowString(time.Now())})
				data, _ := json.Marshal(f.s.state)
				if err := f.p.Save(data); err != nil {
					t.Fatal(err)
				}
			case "bad_idempotency_reference":
				// A bad cached reference must reject without invoking any mutation.
				s, p := testService(t)
				actor := testActor(s, "admin")
				_, _, err := s.transact(actor, "POST /api/v38/orders/wo_quote/actions", "bad-ref", []byte(`{}`), 200, func(st *State) (any, error) { return map[string]any{"id": "wo_quote"}, nil })
				if err != nil {
					t.Fatal(err)
				}
				key := actor.ID + ":POST /api/v38/orders/wo_quote/actions:bad-ref"
				request := s.state.Requests[key]
				request.Body = json.RawMessage(`{"id":"wo_no_such_resource"}`)
				s.state.Requests[key] = request
				data, _ := json.Marshal(s.state)
				if err := p.Save(data); err != nil {
					t.Fatal(err)
				}
				restarted, err := New(p)
				if err != nil {
					t.Fatal(err)
				}
				_, _, err = restarted.transact(testActor(restarted, "admin"), "POST /api/v38/orders/wo_quote/actions", "bad-ref", []byte(`{}`), 200, func(st *State) (any, error) { t.Fatal("bad reference caused mutation execution"); return nil, nil })
				expectCode(t, err, "not_found")
				return
			}
			target := filepath.Join(f.root, "refused-target")
			if err := RestoreBackup(f.bak, f.key, f.data, target); err == nil {
				t.Fatal("corrupt recovery input accepted")
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("failed recovery created an exposable target")
			}
		})
	}
}

func TestRestoreSecondFailedCashTransactionLeavesNoMutationOrConsumedKey(t *testing.T) {
	s, p := testService(t)
	original := testOrder(t, s, "wo_quote")
	payload := map[string]any{"amountCents": 1000, "kind": "receipt", "purpose": "合成保存失败验证", "receipt": "SYNTHETIC-FAILED-SAVE", "occurredAt": nowString(s.now())}
	p.fail = true
	_, err := testActVersion(s, testActor(s, "engineer"), original.ID, "cash", payload, original.Version, "failed-save-key")
	if err == nil {
		t.Fatal("simulated save failure not returned")
	}
	if got := testOrder(t, s, original.ID); len(got.Cash) != 0 || got.Version != original.Version || len(s.state.Requests) != 0 {
		t.Fatal("failed cash save partially committed")
	}
	p.fail = false
	result, err := testActVersion(s, testActor(s, "engineer"), original.ID, "cash", payload, original.Version, "failed-save-key")
	if err != nil || len(result.Cash) != 1 {
		t.Fatal("failed save consumed key or lost retry")
	}
	_ = strings.Builder{}
}
