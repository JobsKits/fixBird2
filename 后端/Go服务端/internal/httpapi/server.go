package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/ledger"
	"repair-platform/internal/payment"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

type Server struct {
	marketplace        *service.Marketplace
	adminWebDir        string
	webDir             string
	identity           *identity.Service
	workers            *workers.Service
	allowAnonymousDemo bool
	ledgerService      *ledger.Service
}

func New(marketplace *service.Marketplace, adminWebDir string) *Server {
	return &Server{
		marketplace:        marketplace,
		adminWebDir:        adminWebDir,
		allowAnonymousDemo: true,
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	s.registerIdentityRoutes(mux)
	s.registerWorkerRoutes(mux)
	s.registerLedgerRoutes(mux)
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /readyz", s.ready)
	mux.HandleFunc("GET /api/v1/categories", s.categories)
	mux.HandleFunc("GET /api/v1/orders", s.listOrders)
	mux.HandleFunc("POST /api/v1/orders", s.createOrder)
	mux.HandleFunc("POST /api/v1/orders/{id}/{action}", s.transitionOrder)
	mux.HandleFunc("POST /api/v1/payment-intents", s.createPaymentIntent)
	mux.HandleFunc("GET /api/v1/admin/dashboard", s.adminDashboard)
	mux.HandleFunc("GET /api/v1/admin/orders", s.adminOrders)
	mux.HandleFunc("GET /api/v1/admin/workers", s.adminWorkers)
	mux.HandleFunc("GET /api/v1/admin/settlements", s.adminSettlements)
	mux.HandleFunc("POST /api/v1/admin/orders/{id}/demo-collect", s.demoCollect)
	mux.HandleFunc("POST /api/v1/admin/settlements/{id}/manual-paid", s.manualPayout)
	mux.HandleFunc("GET /admin", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/admin/", http.StatusTemporaryRedirect)
	})
	mux.Handle("GET /admin/", http.StripPrefix("/admin/", http.FileServer(http.Dir(s.adminWebDir))))
	if s.webDir != "" {
		mux.HandleFunc("GET /portal", func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "/portal/", http.StatusTemporaryRedirect)
		})
		mux.Handle("GET /portal/", http.StripPrefix("/portal/", http.FileServer(http.Dir(s.webDir))))
	}
	return securityHeaders(s.withIdentity(mux))
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "service": "repair-platform"})
}

func (s *Server) categories(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, domain.Categories)
}

func (s *Server) listOrders(w http.ResponseWriter, r *http.Request) {
	query, err := parseListQuery(r, false)
	if err != nil {
		writeError(w, err)
		return
	}
	orders, err := s.marketplace.ListOrders(r.Context(), actorFrom(r), query)
	if err != nil {
		writeError(w, err)
		return
	}
	orders = orderPage(w, orders, query.PageSize())
	writeJSON(w, http.StatusOK, orders)
}

func (s *Server) createOrder(w http.ResponseWriter, r *http.Request) {
	var input domain.CreateOrderInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	order, err := s.marketplace.CreateOrder(r.Context(), actorFrom(r), input, r.Header.Get("Idempotency-Key"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, order)
}

func (s *Server) transitionOrder(w http.ResponseWriter, r *http.Request) {
	action := r.PathValue("action")
	var payload struct {
		QuoteCents int64 `json:"quoteCents"`
	}
	if action == "quote" {
		if err := decodeJSON(w, r, &payload); err != nil {
			writeError(w, err)
			return
		}
	} else if r.ContentLength != 0 {
		if err := decodeJSON(w, r, &struct{}{}); err != nil {
			writeError(w, err)
			return
		}
	}
	order, err := s.marketplace.Transition(
		r.Context(),
		actorFrom(r),
		r.PathValue("id"),
		action,
		payload.QuoteCents,
	)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, order)
}

func (s *Server) createPaymentIntent(w http.ResponseWriter, r *http.Request) {
	var input domain.PaymentIntentInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	intent, err := s.marketplace.CreatePaymentIntent(r.Context(), actorFrom(r), input)
	if err != nil {
		if errors.Is(err, service.ErrPaymentPending) || errors.Is(err, payment.ErrProviderNotConfigured) {
			writeJSON(w, http.StatusNotImplemented, map[string]string{
				"error":     "payment_not_configured",
				"code":      "payment_not_configured",
				"provider":  strings.ToLower(input.Provider),
				"message":   "支付渠道接口已预留，当前版本不会实际扣款",
				"requestId": w.Header().Get("X-Request-ID"),
			})
			return
		}
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, intent)
}

func (s *Server) adminDashboard(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	dashboard, err := s.marketplace.Dashboard(r.Context())
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dashboard)
}

func (s *Server) adminOrders(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	s.listOrders(w, r)
}

func (s *Server) adminWorkers(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	query, err := parseListQuery(r, true)
	if err != nil {
		writeError(w, err)
		return
	}
	workers, err := s.marketplace.ListWorkers(r.Context(), query)
	if err != nil {
		writeError(w, err)
		return
	}
	if len(workers) > query.PageSize() {
		workers = workers[:query.PageSize()]
		setCursor(w, domain.Cursor{ID: workers[len(workers)-1].ID})
	}
	writeJSON(w, http.StatusOK, workers)
}

func (s *Server) adminSettlements(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	query, err := parseListQuery(r, false)
	if err != nil {
		writeError(w, err)
		return
	}
	settlements, err := s.marketplace.ListSettlements(r.Context(), query)
	if err != nil {
		writeError(w, err)
		return
	}
	if len(settlements) > query.PageSize() {
		settlements = settlements[:query.PageSize()]
		last := settlements[len(settlements)-1]
		setCursor(w, domain.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
	}
	writeJSON(w, http.StatusOK, settlements)
}

func (s *Server) demoCollect(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	if r.ContentLength != 0 {
		if err := decodeJSON(w, r, &struct{}{}); err != nil {
			writeError(w, err)
			return
		}
	}
	order, err := s.marketplace.DemoCollect(r.Context(), actorFrom(r), r.PathValue("id"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, order)
}

func (s *Server) manualPayout(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	if r.ContentLength != 0 {
		if err := decodeJSON(w, r, &struct{}{}); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := s.marketplace.MarkSettlementManuallyPaid(
		r.Context(),
		actorFrom(r),
		r.PathValue("id"),
	); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func actorFrom(r *http.Request) domain.Actor {
	if value, ok := r.Context().Value(principalKey{}).(principal); ok {
		return value.Actor
	}
	return domain.Actor{}
}

func requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	return requireOperationsSession(w, r)
}

const MaxJSONBytes int64 = 64 << 10

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, MaxJSONBytes)
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return classifyJSONError(err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err != nil {
			return classifyJSONError(err)
		}
		return fmt.Errorf("%w: one JSON object is required", service.ErrInvalidInput)
	}
	return nil
}

var ErrBodyTooLarge = errors.New("request body is too large")

func classifyJSONError(err error) error {
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return err
	}
	var networkError net.Error
	if errors.As(err, &networkError) && networkError.Timeout() {
		return context.DeadlineExceeded
	}
	var maxBytes *http.MaxBytesError
	if errors.As(err, &maxBytes) {
		return ErrBodyTooLarge
	}
	return fmt.Errorf("%w: invalid JSON: %v", service.ErrInvalidInput, err)
}

func writeError(w http.ResponseWriter, err error) {
	status, code, message := http.StatusInternalServerError, "internal_error", "服务器暂时无法处理请求"
	switch {
	case errors.Is(err, ledger.ErrUncertain):
		status, code, message = http.StatusServiceUnavailable, "retryable", "账务结果尚无法确认，请刷新查询后重试"
	case errors.Is(err, ledger.ErrInvalidState), errors.Is(err, ledger.ErrIdempotencyConflict):
		status, code, message = http.StatusConflict, "invalid_state", "账务状态或重复事件的金额不一致"
	case errors.Is(err, ledger.ErrAmountOverflow):
		status, code, message = http.StatusInternalServerError, "amount_overflow", "账务汇总超出支持范围"
	case errors.Is(err, identity.ErrUnauthenticated), errors.Is(err, identity.ErrCredentials):
		status, code, message = http.StatusUnauthorized, "unauthenticated", "需要有效登录会话，或账号密码不正确"
	case errors.Is(err, identity.ErrAccountDisabled):
		status, code, message = http.StatusForbidden, "account_pending", "账号已封停，请联系管理员"
	case errors.Is(err, identity.ErrUsernameTaken):
		status, code, message = http.StatusConflict, "username_taken", "账号已注册，请登录"
	case errors.Is(err, identity.ErrRateLimited):
		status, code, message = http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后再试"
	case errors.Is(err, workers.ErrRevisionConflict):
		status, code, message = http.StatusConflict, "revision_conflict", "申请资料已经更新，请刷新后重新审核"
	case errors.Is(err, workers.ErrImageTooLarge):
		status, code, message = http.StatusRequestEntityTooLarge, "image_too_large", "图片不得超过5 MiB"
	case errors.Is(err, service.ErrWorkerNotApproved), errors.Is(err, repository.ErrWorkerNotApproved):
		status, code, message = http.StatusForbidden, "worker_not_approved", "师傅资料尚未审核通过，暂时无法接单"
	case errors.Is(err, ErrBodyTooLarge):
		status, code, message = http.StatusRequestEntityTooLarge, "body_too_large", "请求正文超过64 KiB"
	case errors.Is(err, service.ErrInvalidInput):
		status, code, message = http.StatusBadRequest, "invalid_input", err.Error()
	case errors.Is(err, service.ErrForbidden):
		status, code, message = http.StatusForbidden, "forbidden", "当前账号不允许执行此操作"
	case errors.Is(err, repository.ErrIdempotencyConflict):
		status, code, message = http.StatusConflict, "idempotency_conflict", "该幂等键已经用于不同的下单内容"
	case errors.Is(err, repository.ErrRetryable):
		status, code, message = http.StatusServiceUnavailable, "retryable", "操作结果暂时无法确认，请保留相同幂等键查询或重试"
	case errors.Is(err, repository.ErrNotFound):
		status, code, message = http.StatusNotFound, "not_found", "记录不存在"
	case errors.Is(err, repository.ErrInvalidState):
		status, code, message = http.StatusConflict, "invalid_state", "订单状态已变化，请刷新后重试"
	case errors.Is(err, service.ErrPaymentPending):
		status, code, message = http.StatusNotImplemented, "payment_not_configured", "支付渠道尚未接入"
	case errors.Is(err, domain.ErrAmountOverflow):
		status, code, message = http.StatusInternalServerError, "amount_overflow", "金额汇总超出支持范围"
	case errors.Is(err, context.DeadlineExceeded):
		status, code, message = http.StatusGatewayTimeout, "request_timeout", "请求处理超时，请查询结果后重试"
	case errors.Is(err, context.Canceled):
		status, code, message = http.StatusRequestTimeout, "request_cancelled", "请求已取消"
	}
	log.Printf("request=%s code=%s error=%v", w.Header().Get("X-Request-ID"), code, err)
	writeJSON(w, status, map[string]string{"error": message, "message": message, "code": code, "requestId": w.Header().Get("X-Request-ID")})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
		defer cancel()
		value := make([]byte, 12)
		_, _ = rand.Read(value)
		w.Header().Set("X-Request-ID", hex.EncodeToString(value))
		_ = http.NewResponseController(w).SetReadDeadline(time.Now().Add(8 * time.Second))
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
