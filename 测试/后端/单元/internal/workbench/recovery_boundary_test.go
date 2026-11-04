package workbench

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestRecoveryFenceSurvivesRepeatedRestoreAndMissingResource(t *testing.T) {
	f := newRestoreFixture(t)
	f.backup(t)
	actor := testActor(f.s, "customer")
	input := CreateOrderInput{Type: "mail", Customer: "合成新工单客户", Device: "备份后创建的合成设备", Description: "独立恢复边界验证"}
	raw, _ := json.Marshal(input)
	created, _, err := f.s.transact(actor, "POST /api/v38/orders", "created-after-backup", raw, 201, func(st *State) (any, error) { return f.s.createOrder(st, actor, input) })
	if err != nil {
		t.Fatal(err)
	}
	var original Order
	if err := json.Unmarshal(created, &original); err != nil {
		t.Fatal(err)
	}
	first := f.restore(t, "missing-resource")
	key := actor.ID + ":POST /api/v38/orders:created-after-backup"
	if first.state.Requests[key].RecoveryState != recoveryReconciliation {
		t.Fatal("latest-only creation intent did not retain recovery fence")
	}
	check := func(s *Service) {
		t.Helper()
		before := len(s.state.Orders)
		_, _, err := s.transact(testActor(s, "customer"), "POST /api/v38/orders", "created-after-backup", raw, 201, func(st *State) (any, error) {
			t.Fatal("missing original resource was silently created again")
			return nil, nil
		})
		expectCode(t, err, "recovery_reconciliation_required")
		if len(s.state.Orders) != before {
			t.Fatal("recovery fence changed business state")
		}
		_, _, err = s.transact(testActor(s, "customer"), "POST /api/v38/orders", "created-after-backup", []byte(`{"different":true}`), 201, func(st *State) (any, error) {
			t.Fatal("recovered key with different content executed")
			return nil, nil
		})
		expectCode(t, err, "idempotency_conflict")
	}
	check(first)
	secondBackup := filepath.Join(f.root, "second.wbbak")
	if _, err := WriteBackup(first.persistence, f.key, secondBackup); err != nil {
		t.Fatal(err)
	}
	// A second recovery also receives the original later source; it must not
	// turn an already fenced intent into a successful old-snapshot result.
	target := filepath.Join(f.root, "second-target")
	if err := RestoreBackup(secondBackup, f.key, f.data, target); err != nil {
		t.Fatal(err)
	}
	p, err := NewFilePersistence(target, f.key)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	second, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	if second.state.Requests[key].RecoveryState != recoveryReconciliation {
		t.Fatal("subsequent recovery removed reconciliation fence")
	}
	for _, order := range second.state.Orders {
		if order.ID == original.ID {
			t.Fatal("post-backup creation appeared without a restored business fact")
		}
	}
	check(second)
}

func TestRecoveryRequestScopeCannotComeFromClientKeyText(t *testing.T) {
	f := newRestoreFixture(t)
	f.backup(t)
	// The suffix contains a convincing account route, but the trusted scope is
	// the transaction's actual path at the beginning of the persisted key.
	actor := testActor(f.s, "admin")
	clientKey := "POST /api/v38/accounts/customer/status:looks-like-account"
	raw := []byte(`{"intent":"synthetic-other-business"}`)
	_, _, err := f.s.transact(actor, "POST /synthetic-other-business", clientKey, raw, 200, func(st *State) (any, error) {
		return testActor(f.s, "customer"), nil
	})
	if err != nil {
		t.Fatal(err)
	}
	restored := f.restore(t, "scope")
	_, _, err = restored.transact(testActor(restored, "admin"), "POST /synthetic-other-business", clientKey, raw, 200, func(st *State) (any, error) {
		t.Fatal("misclassified client-key path executed")
		return nil, nil
	})
	expectCode(t, err, "recovery_reconciliation_required")
}

func TestRecoveryRejectsConflictingOrMissingConsumedIntentLedger(t *testing.T) {
	for _, kind := range []string{"missing_latest", "wrong_type", "different_hash", "malformed_record"} {
		t.Run(kind, func(t *testing.T) {
			f := newRestoreFixture(t)
			mustAct(t, f.s, "dispatcher", "wo_quote", "remark", map[string]any{"remark": "合成键冲突恢复验证"})
			f.backup(t)
			raw, _ := f.p.Load()
			var current map[string]any
			if err := json.Unmarshal(raw, &current); err != nil {
				t.Fatal(err)
			}
			switch kind {
			case "missing_latest":
				delete(current, "idempotency")
			case "wrong_type":
				current["idempotency"] = []any{}
			case "different_hash", "malformed_record":
				for _, item := range current["idempotency"].(map[string]any) {
					request := item.(map[string]any)
					if kind == "different_hash" {
						request["hash"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
					} else {
						delete(request, "body")
					}
					break
				}
			}
			raw, _ = json.Marshal(current)
			if err := f.p.Save(raw); err != nil {
				t.Fatal(err)
			}
			target := filepath.Join(f.root, "rejected-ledger")
			if err := RestoreBackup(f.bak, f.key, f.data, target); err == nil {
				t.Fatal("incomplete or conflicting consumed-intent source accepted")
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("failed recovery created a target")
			}
		})
	}
}

func TestAccountsRequireValidStructureAndExplicitActiveAtEveryBoundary(t *testing.T) {
	s, p := testService(t)
	baseline, _ := json.Marshal(s.state)
	for _, field := range []string{"id", "username", "name", "companyId", "status", "role", "authVersion"} {
		t.Run("startup_missing_"+field, func(t *testing.T) {
			var raw map[string]any
			_ = json.Unmarshal(baseline, &raw)
			actor := raw["accounts"].([]any)[0].(map[string]any)["actor"].(map[string]any)
			delete(actor, field)
			data, _ := json.Marshal(raw)
			if _, err := New(&testPersistence{data: data}); err == nil {
				t.Fatal("incomplete account accepted at startup")
			}
		})
	}
	for _, status := range []string{"", "unknown", "pending", "disabled"} {
		t.Run("runtime_"+status, func(t *testing.T) {
			fresh, err := New(&testPersistence{data: baseline})
			if err != nil {
				t.Fatal(err)
			}
			actor := testActor(fresh, "admin")
			token, _, err := fresh.login("admin", "Demo-Repair-2026!", "active-contract")
			if err != nil {
				t.Fatal(err)
			}
			for i := range fresh.state.Accounts {
				if fresh.state.Accounts[i].Actor.ID == "admin" {
					fresh.state.Accounts[i].Actor.Status = status
				}
			}
			if _, _, err := fresh.login("admin", "Demo-Repair-2026!", "active-contract"); err == nil {
				t.Fatal("non-active account logged in")
			}
			if _, err := fresh.authenticate(token); err == nil {
				t.Fatal("non-active session authenticated")
			}
			if _, err := fresh.currentActorLocked(actor); err == nil {
				t.Fatal("non-active account passed read guard")
			}
			_, _, err = fresh.transact(actor, "POST /synthetic", "non-active", []byte(`{}`), 200, func(st *State) (any, error) {
				t.Fatal("non-active account reached mutation")
				return nil, nil
			})
			expectCode(t, err, "unauthenticated")
		})
	}
	// A valid persisted account keeps its credentials and status on restart.
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := restarted.login("admin", "Demo-Repair-2026!", "active-contract"); err != nil {
		t.Fatal("valid existing credential changed")
	}
}

func TestRecoveryRejectsMissingDuplicateOrInvalidLatestAccounts(t *testing.T) {
	for _, kind := range []string{"missing_old_id", "duplicate_id", "duplicate_login", "invalid_role", "invalid_status", "zero_auth_version", "missing_hash", "empty_salt"} {
		t.Run(kind, func(t *testing.T) {
			f := newRestoreFixture(t)
			f.backup(t)
			accounts := append([]Account{}, f.s.state.Accounts...)
			switch kind {
			case "missing_old_id":
				accounts = accounts[1:]
			case "duplicate_id":
				accounts[1].Actor.ID = accounts[0].Actor.ID
			case "duplicate_login":
				accounts[1].Actor.Username = accounts[0].Actor.Username
			case "invalid_role":
				accounts[0].Actor.Role = "unknown"
			case "invalid_status":
				accounts[0].Actor.Status = "pending"
			case "zero_auth_version":
				accounts[0].Actor.AuthVersion = 0
			case "missing_hash":
				accounts[0].Hash = ""
			case "empty_salt":
				accounts[0].Salt = ""
			}
			state := f.s.state
			state.Accounts = accounts
			raw, _ := json.Marshal(state)
			if err := f.p.Save(raw); err != nil {
				t.Fatal(err)
			}
			target := filepath.Join(f.root, "invalid-current")
			if err := RestoreBackup(f.bak, f.key, f.data, target); err == nil {
				t.Fatal("invalid current account constraints accepted")
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("invalid current constraints produced a recovery target")
			}
		})
	}
}
