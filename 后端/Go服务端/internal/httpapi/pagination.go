package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/service"
)

func parseListQuery(r *http.Request, workerCursor bool) (domain.ListQuery, error) {
	query := domain.ListQuery{Limit: domain.DefaultPageSize, Status: domain.OrderStatus(r.URL.Query().Get("status"))}
	if value := r.URL.Query().Get("limit"); value != "" {
		limit, err := strconv.Atoi(value)
		if err != nil || limit < 1 || limit > domain.MaxPageSize {
			return query, fmt.Errorf("%w: limit must be 1..200", service.ErrInvalidInput)
		}
		query.Limit = limit
	}
	if query.Status != "" {
		valid := false
		for _, status := range []domain.OrderStatus{domain.StatusPendingWorker, domain.StatusAccepted, domain.StatusArrived, domain.StatusQuotePending, domain.StatusInService, domain.StatusAwaitingPay, domain.StatusCompleted, domain.StatusCancelled} {
			if status == query.Status {
				valid = true
			}
		}
		if !valid || workerCursor || r.URL.Path == "/api/v1/admin/settlements" {
			return query, fmt.Errorf("%w: unsupported status filter", service.ErrInvalidInput)
		}
	}
	if value := r.URL.Query().Get("cursor"); value != "" {
		if len(value) > 512 {
			return query, fmt.Errorf("%w: invalid cursor", service.ErrInvalidInput)
		}
		payload, err := base64.RawURLEncoding.DecodeString(value)
		if err != nil {
			return query, fmt.Errorf("%w: invalid cursor", service.ErrInvalidInput)
		}
		var cursor domain.Cursor
		decoder := json.NewDecoder(bytes.NewReader(payload))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&cursor); err != nil || cursor.ID == "" || len(cursor.ID) > 64 || (!workerCursor && cursor.CreatedAt.IsZero()) {
			return query, fmt.Errorf("%w: invalid cursor", service.ErrInvalidInput)
		}
		var extra any
		if err := decoder.Decode(&extra); err != io.EOF {
			return query, fmt.Errorf("%w: invalid cursor", service.ErrInvalidInput)
		}
		query.Before = &cursor
	}
	return query, nil
}

func setCursor(w http.ResponseWriter, cursor domain.Cursor) {
	payload, _ := json.Marshal(cursor)
	w.Header().Set("X-Next-Cursor", base64.RawURLEncoding.EncodeToString(payload))
}

func orderPage(w http.ResponseWriter, orders []domain.Order, limit int) []domain.Order {
	if len(orders) > limit {
		orders = orders[:limit]
		last := orders[len(orders)-1]
		setCursor(w, domain.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
	}
	return orders
}

func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	checks := []func(context.Context) error{s.marketplace.Ready}
	if s.identity != nil {
		checks = append(checks, s.identity.Ready)
	}
	if s.workers != nil {
		checks = append(checks, s.workers.Ready)
	}
	if s.ledgerService != nil {
		checks = append(checks, s.ledgerService.Ready)
	}
	var failure error
	for _, check := range checks {
		if err := check(ctx); err != nil {
			failure = err
			break
		}
	}
	if failure != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready", "code": "repository_not_ready", "message": "仓储或数据库结构尚未就绪", "requestId": w.Header().Get("X-Request-ID")})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready", "service": "repair-platform"})
}
