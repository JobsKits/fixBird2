package workbench

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
)

const requestWarningThreshold = 10000

const (
	recoveryCurrentAuthorization = "current_authorization"
	recoveryReconciliation       = "reconciliation_required"
)

// Keep every key/hash; historical response graphs are replaced by stable IDs.
func compactResponse(body json.RawMessage) json.RawMessage {
	var ref struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(body, &ref) == nil && (strings.HasPrefix(ref.ID, "wo_") || strings.HasPrefix(ref.ID, "loan_") || strings.HasPrefix(ref.ID, "purchase_")) {
		value, _ := json.Marshal(ref)
		return value
	}
	return body
}

func compactRequests(state *State) {
	for key, request := range state.Requests {
		request.Body = compactResponse(request.Body)
		state.Requests[key] = request
	}
}

func (s *Service) replayRequest(actor Actor, path string, request CachedRequest) (json.RawMessage, int, error) {
	if err := validateCachedRequest(request); err != nil {
		return nil, 0, fail(409, "retry_result_unavailable", "旧请求记录不完整；不会重新执行，请由负责人核对")
	}
	var ref struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(request.Body, &ref)
	accountStatusPath := "POST /api/v38/accounts/" + ref.ID + "/status"
	if request.RecoveryState == recoveryCurrentAuthorization && (ref.ID == "" || path != accountStatusPath) {
		return nil, 0, fail(409, "retry_result_unavailable", "恢复请求授权范围不匹配；不会重新执行，请由负责人核对")
	}
	if request.RecoveryState == recoveryReconciliation {
		if strings.HasPrefix(ref.ID, "wo_") {
			for _, order := range s.state.Orders {
				if order.ID == ref.ID && !visible(order, actor) {
					return nil, 0, fail(404, "not_found", "工单不存在或无访问权限")
				}
			}
		}
		return nil, 0, fail(409, "recovery_reconciliation_required", "此请求恢复前已处理，但对应业务未确认恢复；不会再次执行，请由负责人核对恢复差异")
	}
	var value any
	switch {
	case ref.ID != "" && path == accountStatusPath:
		if err := roles(actor, "admin"); err != nil {
			return nil, 0, err
		}
		for _, account := range s.state.Accounts {
			if account.Actor.ID == ref.ID {
				value = account.Actor
				break
			}
		}
	case strings.HasPrefix(ref.ID, "wo_"):
		order, err := findOrder(&s.state, ref.ID, actor)
		if err != nil {
			return nil, 0, err
		}
		if err = s.auditLocked(actor, "idempotent_order_read", order.ID, "success"); err != nil {
			return nil, 0, err
		}
		value = s.view(*order, &s.state, actor)
	case strings.HasPrefix(ref.ID, "loan_"):
		for _, loan := range s.state.Loans {
			if loan.ID == ref.ID && (actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "dispatcher" || actor.Role == "engineer" && loan.BorrowerID == actor.ID) {
				value = loan
				break
			}
		}
	case strings.HasPrefix(ref.ID, "purchase_"):
		for _, purchase := range s.state.Purchases {
			if purchase.ID == ref.ID && (actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "finance" || actor.Role == "dispatcher" || actor.Role == "supplier" && (purchase.Supplier == actor.ID || purchase.Supplier == actor.Name)) {
				value = purchase
				break
			}
		}
	case strings.HasSuffix(path, "/settings"):
		if err := roles(actor, "admin"); err != nil {
			return nil, 0, err
		}
		value = s.state.Settings
	case strings.HasSuffix(path, "/auto-accept"):
		if err := roles(actor, "admin", "dispatcher"); err != nil {
			return nil, 0, err
		}
		return append(json.RawMessage(nil), request.Body...), request.Status, nil
	default:
		return nil, 0, fail(409, "retry_result_unavailable", "旧请求结果不能安全重建，请由负责人核对；不会重新执行")
	}
	if value == nil {
		return nil, 0, fail(404, "not_found", "原请求资源不存在或已撤销访问；不会重新执行")
	}
	body, err := json.Marshal(value)
	return body, request.Status, err
}

func validateCachedRequest(request CachedRequest) error {
	hash, err := hex.DecodeString(request.Hash)
	if err != nil || len(hash) != sha256.Size || request.Status < 200 || request.Status >= 300 || request.At.IsZero() || !json.Valid(request.Body) {
		return fmt.Errorf("幂等请求记录缺失或格式错误")
	}
	if request.RecoveryState != "" && request.RecoveryState != recoveryCurrentAuthorization && request.RecoveryState != recoveryReconciliation {
		return fmt.Errorf("幂等恢复约束格式错误")
	}
	return nil
}

func (s *Service) capacity() map[string]any {
	count := len(s.state.Requests)
	return map[string]any{"requestCount": count, "threshold": requestWarningThreshold, "warning": count >= requestWarningThreshold*8/10, "mode": "retained_compact_keys"}
}
