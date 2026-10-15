package workbench

import (
	"encoding/json"
	"strings"
	"testing"
)

func permissionMutationSeed(t *testing.T) []byte {
	t.Helper()
	service, _ := testService(t)
	raw, err := json.Marshal(service.state)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func permissionMutationService(t *testing.T, seed []byte) (*Service, *testPersistence) {
	t.Helper()
	persistence := &testPersistence{data: append([]byte(nil), seed...)}
	service, err := New(persistence)
	if err != nil {
		t.Fatal(err)
	}
	return service, persistence
}

func TestInternalRemarkFieldPatchRoleMatrix(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, role := range []string{"admin", "dispatcher", "finance", "engineer", "warehouse", "qc"} {
		t.Run(role, func(t *testing.T) {
			s, p := permissionMutationService(t, seed)
			order := secondPermissionsFixture(s)
			actor := testActor(s, role)
			beforeSaves := p.saves
			_, err := testActVersion(s, actor, order.ID, "remark", map[string]any{"remark": "authorized internal replacement", "customerNote": "public replacement"}, order.Version, "remark-field-policy")
			stored := testOrder(t, s, order.ID)
			if role == "warehouse" || role == "qc" {
				expectCode(t, err, "internal_remark_forbidden")
				if stored.Remark != order.Remark || stored.CustomerNote != order.CustomerNote || stored.Version != order.Version || p.saves != beforeSaves {
					t.Fatal("rejected field edit partially committed")
				}
			} else if err != nil || stored.Remark != "authorized internal replacement" || stored.CustomerNote != "public replacement" {
				t.Fatalf("authorized patch failed: %v", err)
			}
		})
	}
}

func TestInternalRemarkMaskedEmptyAndOmittedField(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, role := range []string{"warehouse", "qc"} {
		for _, includeEmpty := range []bool{false, true} {
			t.Run(role+"/masked="+map[bool]string{true: "true", false: "false"}[includeEmpty], func(t *testing.T) {
				s, _ := permissionMutationService(t, seed)
				order := secondPermissionsFixture(s)
				payload := map[string]any{"customerNote": "customer-visible patch"}
				if includeEmpty {
					payload["remark"] = ""
				}
				response, err := testActVersion(s, testActor(s, role), order.ID, "remark", payload, order.Version, "masked-field-patch")
				if err != nil {
					t.Fatal(err)
				}
				stored := testOrder(t, s, order.ID)
				if stored.Remark != order.Remark || stored.CustomerNote != "customer-visible patch" || response.Remark != "" {
					t.Fatal("masked field changed, visible field lost, or response exposed internal remark")
				}
			})
		}
	}
}

func TestInternalRemarkExplicitClearAndOmission(t *testing.T) {
	s, _ := testService(t)
	order := secondPermissionsFixture(s)
	response := mustAct(t, s, "admin", order.ID, "remark", map[string]any{"remark": ""})
	if response.Remark != "" || response.CustomerNote != order.CustomerNote {
		t.Fatal("explicit administrator clear or omitted public field was mishandled")
	}
	response = mustAct(t, s, "admin", order.ID, "remark", map[string]any{"customerNote": ""})
	if response.CustomerNote != "" {
		t.Fatal("explicit empty public note must clear the public field")
	}
	// A reduced limit does not authorize destroying an untouched legacy field.
	s.state.Orders[0].Remark = strings.Repeat("legacy", 30)
	s.state.Settings.RemarkLimit = 100
	_, err := testAct(t, s, "qc", order.ID, "remark", map[string]any{"customerNote": "valid new note"})
	if err != nil || testOrder(t, s, order.ID).Remark != strings.Repeat("legacy", 30) {
		t.Fatalf("untouched legacy hidden field should be preserved: %v", err)
	}
}

func TestObligationResolutionOwnerAndDelegationMatrix(t *testing.T) {
	seed := permissionMutationSeed(t)
	for _, role := range []string{"admin", "dispatcher", "finance", "engineer", "warehouse", "qc"} {
		for _, own := range []bool{false, true} {
			t.Run(role+"/own="+map[bool]string{true: "true", false: "false"}[own], func(t *testing.T) {
				s, p := permissionMutationService(t, seed)
				order := secondPermissionsFixture(s)
				owner := "finance"
				if role == owner {
					owner = "engineer"
				}
				if own {
					owner = role
				}
				s.state.Orders[0].Obligations = []Task{{ID: "task_write_policy", OwnerID: owner, Title: "synthetic owner-specific duty"}}
				actor := testActor(s, role)
				allowed := own || role == "admin" || role == "dispatcher"
				view := s.view(s.state.Orders[0], &s.state, actor)
				hasAction := false
				for _, action := range view.AllowedActions {
					hasAction = hasAction || action == "resolve_obligation"
				}
				if hasAction != allowed {
					t.Fatalf("allowedActions differs from task write authorization: got=%v expected=%v", hasAction, allowed)
				}
				before, _ := json.Marshal(s.state.Orders)
				beforeSaves := p.saves
				result, err := testActVersion(s, actor, order.ID, "resolve_obligation", map[string]any{"obligationId": "task_write_policy", "note": "synthetic completion proof"}, order.Version, "owner-duty-policy")
				if !allowed {
					expectCode(t, err, "obligation_forbidden")
					after, _ := json.Marshal(s.state.Orders)
					if string(before) != string(after) || p.saves != beforeSaves {
						t.Fatal("denied foreign task resolution mutated or persisted state")
					}
					return
				}
				if err != nil || !testOrder(t, s, order.ID).Obligations[0].Resolved {
					t.Fatalf("authorized owner/delegate could not resolve: %v", err)
				}
				for _, action := range result.AllowedActions {
					if action == "resolve_obligation" {
						t.Fatal("resolution action remained without any unresolved authorized duty")
					}
				}
			})
		}
	}
}

func TestObligationResolutionResponseAndRetryRemainRedacted(t *testing.T) {
	s, _ := testService(t)
	order := secondPermissionsFixture(s)
	s.state.Orders[0].Obligations = []Task{{ID: "task_qc_own", OwnerID: "qc", Title: "quality proof"}, {ID: "task_finance_private", OwnerID: "finance", Title: "PRIVATE-FINANCE-DUTY"}}
	actor := testActor(s, "qc")
	payload := map[string]any{"obligationId": "task_qc_own", "note": "quality completion proof"}
	for i := 0; i < 2; i++ {
		view, err := testActVersion(s, actor, order.ID, "resolve_obligation", payload, order.Version, "qc-resolution-once")
		if err != nil {
			t.Fatal(err)
		}
		body, _ := json.Marshal(view)
		if view.Version != order.Version+1 || len(view.Obligations) != 1 || view.Obligations[0].ID != "task_qc_own" || strings.Contains(string(body), "PRIVATE-FINANCE-DUTY") || strings.Contains(string(body), "private-finance-cost-sentinel") {
			t.Fatal("write/replay response leaked a hidden task or changed twice")
		}
	}
	if testOrder(t, s, order.ID).Obligations[1].Resolved {
		t.Fatal("own resolution affected another owner's duty")
	}
}
