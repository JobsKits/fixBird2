package httpapi

import (
	"context"
	"net"
	"net/http"
	"strings"

	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/ledger"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

type principalKey struct{}
type principal struct {
	Actor   domain.Actor
	User    identity.User
	Session bool
}

func (s *Server) SetWebDir(path string) { s.webDir = path }

func (s *Server) SetLedger(service *ledger.Service) { s.ledgerService = service }

func (s *Server) EnableIdentity(accounts *identity.Service, onboarding *workers.Service, allowAnonymousDemo bool) {
	s.identity = accounts
	s.workers = onboarding
	s.allowAnonymousDemo = allowAnonymousDemo
}

func actorFromRequest(r *http.Request) domain.Actor { return actorFrom(r) }

func requireSession(w http.ResponseWriter, r *http.Request) bool {
	value, ok := r.Context().Value(principalKey{}).(principal)
	if ok && value.Session {
		return true
	}
	writeError(w, identity.ErrUnauthenticated)
	return false
}

func requireSessionAdmin(w http.ResponseWriter, r *http.Request) bool {
	if !requireSession(w, r) {
		return false
	}
	if actorFrom(r).Role == domain.RoleAdmin {
		return true
	}
	writeError(w, service.ErrForbidden)
	return false
}

func bearerToken(r *http.Request) string {
	parts := strings.Fields(r.Header.Get("Authorization"))
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return ""
	}
	return parts[1]
}

func (s *Server) withIdentity(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		publicQR := r.Method == http.MethodPost && (r.URL.Path == "/api/v1/auth/qr/challenges" || (strings.HasPrefix(r.URL.Path, "/api/v1/auth/qr/challenges/") && strings.HasSuffix(r.URL.Path, "/poll")))
		if !strings.HasPrefix(r.URL.Path, "/api/v1/") || r.URL.Path == "/api/v1/categories" || r.URL.Path == "/api/v1/auth/login" || r.URL.Path == "/api/v1/auth/register" || r.URL.Path == "/api/v1/auth/password-reset" || publicQR {
			next.ServeHTTP(w, r)
			return
		}
		value := principal{}
		if r.Header.Get("Authorization") != "" {
			if s.identity == nil {
				writeError(w, identity.ErrUnauthenticated)
				return
			}
			user, err := s.identity.Authenticate(r.Context(), bearerToken(r))
			if err != nil {
				writeError(w, err)
				return
			}
			value = principal{Actor: user.Actor(), User: user, Session: true}
		} else {
			role := domain.Role(strings.ToLower(strings.TrimSpace(r.Header.Get("X-Actor-Role"))))
			if role == "" {
				role = domain.RoleCustomer
			}
			id := strings.TrimSpace(r.Header.Get("X-Actor-ID"))
			expected := "customer-demo"
			if role == domain.RoleWorker {
				expected = "worker-demo"
			}
			if id == "" {
				id = expected
			}
			if !s.allowAnonymousDemo || (role != domain.RoleCustomer && role != domain.RoleWorker) || id != expected {
				writeError(w, identity.ErrUnauthenticated)
				return
			}
			value.Actor = domain.Actor{ID: id, Role: role, Demo: true}
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), principalKey{}, value)))
	})
}

func (s *Server) registerIdentityRoutes(mux *http.ServeMux) {
	s.registerAccountManagementRoutes(mux)
	mux.HandleFunc("POST /api/v1/auth/register", s.registerAccount)
	mux.HandleFunc("POST /api/v1/auth/login", s.loginAccount)
	mux.HandleFunc("POST /api/v1/auth/logout", s.logoutAccount)
	mux.HandleFunc("GET /api/v1/auth/me", s.currentAccount)
	mux.HandleFunc("GET /api/v1/auth/devices", s.authDevices)
	mux.HandleFunc("DELETE /api/v1/auth/devices/{id}", s.revokeAuthDevice)
	mux.HandleFunc("POST /api/v1/auth/qr/challenges", s.newQRChallenge)
	mux.HandleFunc("POST /api/v1/auth/qr/challenges/{id}/poll", s.pollQRChallenge)
	mux.HandleFunc("POST /api/v1/auth/qr/challenges/{id}/inspect", s.inspectQRChallenge)
	mux.HandleFunc("POST /api/v1/auth/qr/challenges/{id}/approve", s.approveQRChallenge)
}

func (s *Server) allowAuthAttempt(w http.ResponseWriter, r *http.Request) bool {
	if s.identity == nil {
		writeError(w, identity.ErrUnauthenticated)
		return false
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	// Use the direct peer, never untrusted forwarded IP headers.
	if !s.identity.AllowAttempt(host) {
		w.Header().Set("Retry-After", "60")
		writeError(w, identity.ErrRateLimited)
		return false
	}
	return true
}

func (s *Server) registerAccount(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuthAttempt(w, r) {
		return
	}
	var input identity.RegisterInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.identity.Register(r.Context(), input)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusCreated, result)
}
func (s *Server) loginAccount(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuthAttempt(w, r) {
		return
	}
	var input identity.LoginInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.identity.Login(r.Context(), input)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, result)
}
func (s *Server) currentAccount(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, value.User)
}
func (s *Server) logoutAccount(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if r.ContentLength != 0 {
		if err := decodeJSON(w, r, &struct{}{}); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := s.identity.Logout(r.Context(), bearerToken(r)); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func requireOperationsSession(w http.ResponseWriter, r *http.Request) bool {
	if !requireSession(w, r) {
		return false
	}
	role := actorFrom(r).Role
	if role == domain.RoleAdmin || role == domain.RoleOperator {
		return true
	}
	writeError(w, service.ErrForbidden)
	return false
}
