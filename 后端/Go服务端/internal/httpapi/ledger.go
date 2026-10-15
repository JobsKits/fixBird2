package httpapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/ledger"
	"repair-platform/internal/service"
)

// Read-only journal routes. Reversals remain internal until business-state reversal shares their transaction.
func (s *Server) registerLedgerRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/admin/ledger/journals", func(w http.ResponseWriter, r *http.Request) { s.ledgerList(w, r, true) })
	mux.HandleFunc("GET /api/v1/admin/ledger/summary", func(w http.ResponseWriter, r *http.Request) { s.ledgerSummary(w, r, true) })
	mux.HandleFunc("GET /api/v1/admin/ledger/export.csv", s.ledgerCSV)
	for _, prefix := range []string{"/api/v1/ledger", "/api/v1/me/ledger"} {
		mux.HandleFunc("GET "+prefix+"/journals", func(w http.ResponseWriter, r *http.Request) { s.ledgerList(w, r, false) })
		mux.HandleFunc("GET "+prefix+"/summary", func(w http.ResponseWriter, r *http.Request) { s.ledgerSummary(w, r, false) })
	}
}

func (s *Server) ledgerQuery(w http.ResponseWriter, r *http.Request, admin bool) (ledger.Query, bool) {
	if admin {
		if !requireOperationsSession(w, r) {
			return ledger.Query{}, false
		}
	} else if !requireSession(w, r) {
		return ledger.Query{}, false
	}
	if s.ledgerService == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"code": "ledger_not_ready", "message": "账务尚未初始化"})
		return ledger.Query{}, false
	}
	query, err := parseLedgerQuery(r)
	if err != nil {
		writeLedgerError(w, err)
		return ledger.Query{}, false
	}
	if !admin {
		actor := actorFromRequest(r)
		switch actor.Role {
		case domain.RoleCustomer:
			if query.CustomerID != "" && query.CustomerID != actor.ID {
				writeError(w, service.ErrForbidden)
				return ledger.Query{}, false
			}
			query.CustomerID = actor.ID
		case domain.RoleWorker:
			if query.WorkerID != "" && query.WorkerID != actor.ID {
				writeError(w, service.ErrForbidden)
				return ledger.Query{}, false
			}
			query.WorkerID = actor.ID
		default:
			writeError(w, service.ErrForbidden)
			return ledger.Query{}, false
		}
	}
	return query, true
}

func parseLedgerQuery(r *http.Request) (ledger.Query, error) {
	values := r.URL.Query()
	query := ledger.Query{Mode: values.Get("mode"), Kind: values.Get("kind"), Status: values.Get("status"), Channel: values.Get("channel"),
		OrderID: values.Get("orderId"), CustomerID: values.Get("customerId"), WorkerID: values.Get("workerId")}
	var err error
	if value := values.Get("limit"); value != "" {
		query.Limit, err = strconv.Atoi(value)
		if err != nil {
			return ledger.Query{}, ledger.ErrInvalidInput
		}
	}
	if query.Before, err = ledger.DecodeCursor(values.Get("cursor")); err != nil {
		return ledger.Query{}, err
	}
	for _, field := range []struct {
		name   string
		target *time.Time
	}{{"from", &query.From}, {"to", &query.To}} {
		if value := values.Get(field.name); value != "" {
			*field.target, err = time.Parse(time.RFC3339, value)
			if err != nil {
				return ledger.Query{}, fmt.Errorf("%w: %s must be RFC3339", ledger.ErrInvalidInput, field.name)
			}
		}
	}
	return ledger.NormalizeQuery(query)
}

func (s *Server) ledgerList(w http.ResponseWriter, r *http.Request, admin bool) {
	query, allowed := s.ledgerQuery(w, r, admin)
	if !allowed {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	page, err := s.ledgerService.List(ctx, query)
	if err != nil {
		writeLedgerError(w, err)
		return
	}
	if page.NextCursor != "" {
		w.Header().Set("X-Next-Cursor", page.NextCursor)
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, page.Items)
}

func (s *Server) ledgerSummary(w http.ResponseWriter, r *http.Request, admin bool) {
	query, allowed := s.ledgerQuery(w, r, admin)
	if !allowed {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	summary, err := s.ledgerService.Summary(ctx, query)
	if err != nil {
		writeLedgerError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, summary)
}

func (s *Server) ledgerCSV(w http.ResponseWriter, r *http.Request) {
	query, allowed := s.ledgerQuery(w, r, true)
	if !allowed {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	data, err := s.ledgerService.ExportCSV(ctx, query)
	if err != nil {
		writeLedgerError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="repair-ledger-`+query.Mode+`.csv"`)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func writeLedgerError(w http.ResponseWriter, err error) {
	status, code, message := http.StatusInternalServerError, "ledger_error", "账务暂时不可查询"
	switch {
	case errors.Is(err, ledger.ErrInvalidInput):
		status, code, message = http.StatusBadRequest, "invalid_ledger_filter", err.Error()
	case errors.Is(err, ledger.ErrNotFound):
		status, code, message = http.StatusNotFound, "ledger_not_found", "记账分录不存在"
	case errors.Is(err, ledger.ErrInvalidState):
		status, code, message = http.StatusConflict, "ledger_state_conflict", "账务状态不允许此操作"
	case errors.Is(err, ledger.ErrIdempotencyConflict):
		status, code, message = http.StatusConflict, "ledger_idempotency_conflict", "事件键已用于不同账务内容"
	case errors.Is(err, ledger.ErrRealNotConfigured):
		status, code, message = http.StatusNotImplemented, "real_accounting_not_configured", "真实支付账务尚未启用"
	case errors.Is(err, ledger.ErrExportTooLarge):
		status, code, message = http.StatusRequestEntityTooLarge, "ledger_export_too_large", "导出超过10000条，请缩小筛选范围"
	case errors.Is(err, ledger.ErrUncertain):
		status, code, message = http.StatusServiceUnavailable, "ledger_outcome_uncertain", "记账结果尚未确认，请保留同一事件键查询"
	case errors.Is(err, context.DeadlineExceeded):
		status, code, message = http.StatusGatewayTimeout, "ledger_timeout", "账务查询超时"
	case errors.Is(err, context.Canceled):
		status, code, message = http.StatusRequestTimeout, "ledger_cancelled", "账务查询已取消"
	}
	writeJSON(w, status, map[string]string{"code": code, "message": message, "requestId": w.Header().Get("X-Request-ID")})
}
