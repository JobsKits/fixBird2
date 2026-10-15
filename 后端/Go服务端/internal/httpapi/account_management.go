package httpapi

import (
	"net/http"
	"repair-platform/internal/identity"
)

func (s *Server) registerAccountManagementRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/auth/password", s.changeOwnPassword)
	mux.HandleFunc("POST /api/v1/auth/password-reset", s.resetPassword)
	mux.HandleFunc("POST /api/v1/auth/recovery-code", s.newRecoveryCode)
	mux.HandleFunc("GET /api/v1/admin/accounts", s.listAccounts)
	mux.HandleFunc("POST /api/v1/admin/accounts", s.addAccount)
	mux.HandleFunc("POST /api/v1/admin/accounts/{username}/status", s.setAccountStatus)
	mux.HandleFunc("POST /api/v1/admin/accounts/{username}/password", s.resetAccountPassword)
}
func (s *Server) resetPassword(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuthAttempt(w, r) {
		return
	}
	var input identity.PasswordResetInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	if err := s.identity.ResetPassword(r.Context(), input); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (s *Server) newRecoveryCode(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if err := decodeJSON(w, r, &struct{}{}); err != nil {
		writeError(w, err)
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	code, err := s.identity.NewRecoveryCode(r.Context(), value.User)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, map[string]string{"recoveryCode": code})
}
func (s *Server) listAccounts(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) {
		return
	}
	user := r.Context().Value(principalKey{}).(principal).User
	values, err := s.identity.Accounts(r.Context(), user, r.URL.Query().Get("cursor"))
	if err != nil {
		writeError(w, err)
		return
	}
	if len(values) > 50 {
		values = values[:50]
		w.Header().Set("X-Next-Cursor", values[49].Username)
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, values)
}
func (s *Server) addAccount(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) || !s.allowAuthAttempt(w, r) {
		return
	}
	var input identity.AccountInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	user := r.Context().Value(principalKey{}).(principal).User
	value, err := s.identity.AddAccount(r.Context(), user, input)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusCreated, value)
}
func (s *Server) setAccountStatus(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) {
		return
	}
	var input struct {
		Status string `json:"status"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	user := r.Context().Value(principalKey{}).(principal).User
	if err := s.identity.SetAccountStatus(r.Context(), user, r.PathValue("username"), input.Status); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (s *Server) resetAccountPassword(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) || !s.allowAuthAttempt(w, r) {
		return
	}
	var input struct {
		Password string `json:"password"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	user := r.Context().Value(principalKey{}).(principal).User
	if err := s.identity.ResetAccountPassword(r.Context(), user, r.PathValue("username"), input.Password); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) changeOwnPassword(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) || !s.allowAuthAttempt(w, r) {
		return
	}
	var input struct {
		CurrentPassword string `json:"currentPassword"`
		Password        string `json:"password"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	user := r.Context().Value(principalKey{}).(principal).User
	if err := s.identity.ChangeOwnPassword(r.Context(), user, input.CurrentPassword, input.Password); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
