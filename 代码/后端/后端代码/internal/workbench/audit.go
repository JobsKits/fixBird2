package workbench

import (
	"encoding/json"
	"fmt"
)

type AuditEvent struct {
	ID          string   `json:"id"`
	ActorID     string   `json:"actorId"`
	ActorRole   string   `json:"actorRole"`
	Type        string   `json:"type"`
	Resource    string   `json:"resource"`
	ResourceIDs []string `json:"resourceIds,omitempty"`
	Result      string   `json:"result"`
	At          string   `json:"at"`
	Reason      string   `json:"reason,omitempty"`
	Before      string   `json:"before,omitempty"`
	After       string   `json:"after,omitempty"`
	AuthBefore  int      `json:"authBefore,omitempty"`
	AuthAfter   int      `json:"authAfter,omitempty"`
}

func (s *Service) appendAudit(state *State, actor Actor, kind, resource, result string) int {
	if actor.ID == "" {
		actor.ID, actor.Role = "anonymous", "anonymous"
	}
	state.Audit = append(state.Audit, AuditEvent{
		ID: randomID("audit_"), ActorID: actor.ID, ActorRole: actor.Role,
		Type: kind, Resource: resource, Result: result, At: nowString(s.now()),
	})
	return len(state.Audit) - 1
}

func normalizeLegacyAudit(state *State) {
	for index := range state.Audit {
		event := &state.Audit[index]
		if event.ActorID == "" && event.ActorRole == "" && event.Result == "denied" && (event.Type == "login" || event.Type == "authentication") {
			event.ActorID, event.ActorRole = "anonymous", "anonymous"
		}
	}
}

// Caller holds the business mutex; save audit before releasing private content.
func (s *Service) auditLocked(actor Actor, kind, resource, result string, resourceIDs ...string) error {
	next := s.state
	next.Audit = append([]AuditEvent(nil), s.state.Audit...)
	index := s.appendAudit(&next, actor, kind, resource, result)
	next.Audit[index].ResourceIDs = append([]string(nil), resourceIDs...)
	raw, err := json.Marshal(next)
	if err != nil {
		return err
	}
	if err = s.persistence.Save(raw); err != nil {
		return fmt.Errorf("save security audit: %w", err)
	}
	s.state = next
	return nil
}

func (s *Service) audit(actor Actor, kind, resource, result string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.auditLocked(actor, kind, resource, result)
}

func (s *Service) currentActorLocked(actor Actor) (Actor, error) {
	for _, account := range s.state.Accounts {
		current := account.Actor
		if current.ID == actor.ID && activeActor(current) && current.AuthVersion == actor.AuthVersion {
			return current, nil
		}
	}
	return Actor{}, fail(401, "unauthenticated", "账号授权已变化，请重新登录")
}
