package workbench

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"testing"
)

func deepRaw(t *testing.T, value any) []byte {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func deepNew(t *testing.T, raw []byte) (*Service, *testPersistence) {
	t.Helper()
	p := &testPersistence{data: append([]byte(nil), raw...)}
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return s, p
}

func deepAction(t *testing.T, s *Service, actor Actor, id, key string, action Action) ([]byte, error) {
	t.Helper()
	raw := deepRaw(t, action)
	response, _, err := s.transact(actor, "POST /api/v38/orders/"+id+"/actions", key, raw, 200, func(st *State) (any, error) {
		return s.act(st, actor, id, action)
	})
	return response, err
}

func deepChangePrincipal(s *Service, id, role, status string) {
	for index := range s.state.Accounts {
		if s.state.Accounts[index].Actor.ID == id {
			s.state.Accounts[index].Actor.Role = role
			s.state.Accounts[index].Actor.Status = status
			s.state.Accounts[index].Actor.AuthVersion++
		}
	}
}

func TestBackendDeepDemotedPrincipalRestartedSameKeyReplay(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, role := range []string{"qc", "warehouse", "engineer", "supplier"} {
		t.Run("safe_expectation/"+role, func(t *testing.T) {
			s, _ := deepNew(t, seed)
			order := secondPermissionsFixture(s)
			old := testActor(s, "admin")
			action := Action{Type: "cost", Version: order.Version, Payload: deepRaw(t, map[string]any{"category": "other", "amountCents": 333, "note": "own earlier expense"})}
			if _, err := deepAction(t, s, old, order.ID, "demotion-cost", action); err != nil {
				t.Fatal(err)
			}
			deepChangePrincipal(s, "admin", role, "active")
			if role == "engineer" {
				s.state.Orders[0].AssigneeID = "admin"
			}
			s, _ = deepNew(t, deepRaw(t, s.state))
			before := deepRaw(t, s.state.Orders)
			_, _, stale := s.transact(old, "POST /api/v38/orders/"+order.ID+"/actions", "demotion-cost", deepRaw(t, action), 200, func(*State) (any, error) {
				t.Fatal("stale authorization executed mutation")
				return nil, nil
			})
			expectCode(t, stale, "unauthenticated")
			current := testActor(s, "admin")
			result, _, err := s.transact(current, "POST /api/v38/orders/"+order.ID+"/actions", "demotion-cost", deepRaw(t, action), 200, func(*State) (any, error) {
				t.Fatal("processed cost executed after role downgrade")
				return nil, nil
			})
			if role == "supplier" {
				expectCode(t, err, "not_found")
			} else {
				if err != nil || strings.Contains(string(result), "private-finance-cost-sentinel") || strings.Contains(string(result), "private-commission-note-sentinel") {
					t.Fatalf("fresh principal replay did not use current field scope: %v", err)
				}
				var view Order
				if json.Unmarshal(result, &view) != nil || view.Summary.PendingCashCents != 0 {
					t.Fatal("fresh principal inherited another collector's pending amount")
				}
				if role == "qc" && len(view.Costs) != 0 {
					t.Fatal("QC regained historical administrator expense fields")
				}
			}
			if string(before) != string(deepRaw(t, s.state.Orders)) {
				t.Fatal("read-only cached retry changed business facts")
			}
		})
	}
}

func TestBackendDeepRejectedFailedThenSuccessfulSameIntentAtomicity(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, kind := range []string{"public_only", "masked_empty", "explicit_clear", "own_obligation"} {
		t.Run("safe_expectation/"+kind, func(t *testing.T) {
			s, p := deepNew(t, seed)
			order := secondPermissionsFixture(s)
			role := "qc"
			if kind == "explicit_clear" {
				role = "engineer"
			}
			actor := testActor(s, role)
			bad := Action{Type: "remark", Version: order.Version, Payload: deepRaw(t, map[string]any{"remark": "foreign internal replacement", "customerNote": "new public note"})}
			if role == "qc" {
				_, err := deepAction(t, s, actor, order.ID, "atomic-intent", bad)
				expectCode(t, err, "internal_remark_forbidden")
			}
			payload := map[string]any{"customerNote": "new public note"}
			if kind == "masked_empty" || kind == "explicit_clear" {
				payload["remark"] = ""
			}
			action := Action{Type: "remark", Version: order.Version, Payload: deepRaw(t, payload)}
			if kind == "own_obligation" {
				s.state.Orders[0].Obligations = []Task{{ID: "task_deep_qc", OwnerID: "qc", Title: "quality proof"}}
				action.Type = "resolve_obligation"
				action.Payload = deepRaw(t, map[string]any{"obligationId": "task_deep_qc", "note": "quality completion proof"})
			}
			p.data = deepRaw(t, s.state)
			before := deepRaw(t, s.state)
			p.fail = true
			response, err := deepAction(t, s, actor, order.ID, "atomic-intent", action)
			if err == nil || len(response) != 0 || string(before) != string(deepRaw(t, s.state)) || string(before) != string(p.data) {
				t.Fatal("failed save released result, consumed a key or partially changed memory/storage")
			}
			p.fail = false
			if _, err = deepAction(t, s, actor, order.ID, "atomic-intent", action); err != nil {
				t.Fatalf("rejected/failed intent key should be usable once after recovery: %v", err)
			}
			actual := testOrder(t, s, order.ID)
			if actual.Version != order.Version+1 || kind != "explicit_clear" && actual.Remark != order.Remark {
				t.Fatal("successful corrected intent changed twice or erased hidden remark")
			}
			beforeOrders := deepRaw(t, s.state.Orders)
			if _, err = deepAction(t, s, actor, order.ID, "atomic-intent", action); err != nil || string(beforeOrders) != string(deepRaw(t, s.state.Orders)) {
				t.Fatal("exact processed retry mutated business facts")
			}
		})
	}
}

func TestBackendDeepRestoredAccountRequestUsesCurrentPrincipal(t *testing.T) {
	seed := permissionMutationSeed(t)
	base, _ := deepNew(t, seed)
	backup := deepRaw(t, base.state)
	token := secondPermissionToken(t, base, "admin")
	raw := []byte(`{"status":"disabled","reason":"deep synthetic authorization change"}`)
	first := secondPermissionHTTP(base, token, http.MethodPost, "/api/v38/accounts/customer/status", "restored-auth-key", raw)
	if first.Code != 200 {
		t.Fatal("initial account status operation failed")
	}
	merged, err := mergeRestrictions(backup, deepRaw(t, base.state))
	if err != nil {
		t.Fatal(err)
	}
	for _, state := range []struct{ role, status string }{{"admin", "active"}, {"qc", "active"}, {"finance", "active"}, {"admin", "disabled"}} {
		t.Run("safe_expectation/"+state.role+"/"+state.status, func(t *testing.T) {
			s, _ := deepNew(t, merged)
			deepChangePrincipal(s, "admin", state.role, state.status)
			s, _ = deepNew(t, deepRaw(t, s.state))
			before := deepRaw(t, s.state.Accounts)
			actor := testActor(s, "admin")
			response, _, err := s.transact(actor, "POST /api/v38/accounts/customer/status", "restored-auth-key", raw, 200, func(*State) (any, error) {
				t.Fatal("restored account request re-executed its status change")
				return nil, nil
			})
			if state.status == "disabled" {
				expectCode(t, err, "unauthenticated")
			} else if state.role != "admin" {
				expectCode(t, err, "forbidden")
			} else {
				var current Actor
				if err != nil || json.Unmarshal(response, &current) != nil || current.Status != "disabled" || current.AuthVersion != 2 {
					t.Fatalf("account replay did not return copied current authorization: %v", err)
				}
			}
			if string(before) != string(deepRaw(t, s.state.Accounts)) {
				t.Fatal("restored authorization retry modified copied current accounts")
			}
		})
	}
}

func TestBackendDeepRepeatedRestoreWithPostRestoreIntent(t *testing.T) {
	s, _ := testService(t)
	backup := deepRaw(t, s.state)
	order := testOrder(t, s, "wo_quote")
	cash := Action{Type: "cash", Version: order.Version, Payload: deepRaw(t, map[string]any{"amountCents": 1000, "kind": "receipt", "purpose": "deep synthetic receipt", "receipt": "DEEP-SYNTHETIC", "occurredAt": nowString(s.now())})}
	if _, err := deepAction(t, s, testActor(s, "engineer"), order.ID, "before-restore-cash", cash); err != nil {
		t.Fatal(err)
	}
	first, err := mergeRestrictions(backup, deepRaw(t, s.state))
	if err != nil {
		t.Fatal(err)
	}
	restored, _ := deepNew(t, first)
	patch := Action{Type: "remark", Version: order.Version, Payload: deepRaw(t, map[string]any{"customerNote": "post-restore public patch"})}
	if _, err = deepAction(t, restored, testActor(restored, "qc"), order.ID, "after-restore-note", patch); err != nil {
		t.Fatal(err)
	}
	latest := deepRaw(t, restored.state)
	second, err := mergeRestrictions(first, latest)
	if err != nil {
		t.Fatal(err)
	}
	third, err := mergeRestrictions(second, latest)
	if err != nil {
		t.Fatal(err)
	}
	final, _ := deepNew(t, third)
	beforeOrders := deepRaw(t, final.state.Orders)
	for _, item := range []struct {
		role, key string
		action    Action
	}{{"engineer", "before-restore-cash", cash}, {"qc", "after-restore-note", patch}} {
		_, _, err := final.transact(testActor(final, item.role), "POST /api/v38/orders/"+order.ID+"/actions", item.key, deepRaw(t, item.action), 200, func(*State) (any, error) {
			t.Fatal("historical or post-restore fenced intent executed again")
			return nil, nil
		})
		expectCode(t, err, "recovery_reconciliation_required")
	}
	if string(beforeOrders) != string(deepRaw(t, final.state.Orders)) || len(testOrder(t, final, order.ID).Cash) != 0 || testOrder(t, final, order.ID).CustomerNote == "post-restore public patch" {
		t.Fatal("multiple recoveries invented newer rolled-back business facts")
	}
	restores := 0
	for _, event := range final.state.Audit {
		if event.Type == "backup_restore" {
			restores++
		}
	}
	if restores != 3 {
		t.Fatalf("restore history merged incorrectly: got=%d wanted=3", restores)
	}
}

func TestBackendDeepAccountScopeWithOrderLikeAccountID(t *testing.T) {
	s, _ := testService(t)
	account := s.state.Accounts[0]
	account.Actor.ID = "wo_quote"
	account.Actor.Username = "order-like-account"
	account.Actor.Name = "synthetic order-like account"
	account.Actor.Role = "customer"
	account.Actor.CompanyID = "company-a"
	s.state.Accounts = append(s.state.Accounts, account)
	backup := deepRaw(t, s.state)
	token := secondPermissionToken(t, s, "admin")
	raw := []byte(`{"status":"disabled","reason":"deep exact account route"}`)
	w := secondPermissionHTTP(s, token, http.MethodPost, "/api/v38/accounts/wo_quote/status", "account-order-prefix", raw)
	if w.Code != 200 {
		t.Fatalf("account operation HTTP=%d", w.Code)
	}
	merged, err := mergeRestrictions(backup, deepRaw(t, s.state))
	if err != nil {
		t.Fatal(err)
	}
	final, _ := deepNew(t, merged)
	response, _, err := final.transact(testActor(final, "admin"), "POST /api/v38/accounts/wo_quote/status", "account-order-prefix", raw, 200, func(*State) (any, error) { t.Fatal("account status replay executed"); return nil, nil })
	var actor Actor
	if err != nil || json.Unmarshal(response, &actor) != nil || actor.ID != "wo_quote" || actor.Status != "disabled" || strings.Contains(string(response), "quoteHistory") {
		t.Fatalf("order-like account ID escaped trusted account route: %v", err)
	}
}

func TestBackendDeepPatchParserAndAuthorizationAgree(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, row := range []struct {
		name, payload string
		allowed       bool
		note          string
	}{
		{"null_internal", `{"remark":null,"customerNote":"new public"}`, true, "new public"},
		{"null_public", `{"remark":"","customerNote":null}`, true, "public-customer-note"},
		{"duplicate_empty_last", `{"remark":"forbidden","Remark":"","customerNote":"new public"}`, true, "new public"},
		{"duplicate_nonempty_last", `{"remark":"","Remark":"forbidden","customerNote":"new public"}`, false, ""},
		{"case_public", `{"CUSTOMERNOTE":"new public"}`, true, "new public"},
		{"whitespace_internal", `{"remark":"   ","customerNote":"new public"}`, false, ""},
	} {
		t.Run("safe_expectation/"+row.name, func(t *testing.T) {
			s, p := deepNew(t, seed)
			order := secondPermissionsFixture(s)
			p.data = deepRaw(t, s.state)
			before := deepRaw(t, s.state)
			response, err := deepAction(t, s, testActor(s, "qc"), order.ID, "parser-role", Action{Type: "remark", Version: order.Version, Payload: json.RawMessage(row.payload)})
			if !row.allowed {
				var business *businessError
				if !errors.As(err, &business) || business.Status != 403 || len(response) != 0 || string(before) != string(deepRaw(t, s.state)) || string(before) != string(p.data) {
					t.Fatal("parser/role mismatch partially committed forbidden patch")
				}
				return
			}
			actual := testOrder(t, s, order.ID)
			if err != nil || actual.Remark != order.Remark || actual.CustomerNote != row.note {
				t.Fatalf("nullable/duplicate-case patch erased a hidden field: %v", err)
			}
		})
	}
}
