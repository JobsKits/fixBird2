package httpapi

import (
	"net"
	"net/http"

	"repair-platform/internal/identity"
)

func (s *Server) authDevices(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	devices, err := s.identity.Devices(r.Context(), value.User)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, devices)
}
func (s *Server) revokeAuthDevice(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	if err := s.identity.RevokeDevice(r.Context(), value.User, r.PathValue("id")); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (s *Server) newQRChallenge(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuthAttempt(w, r) {
		return
	}
	var input struct {
		Device identity.Device `json:"device"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.identity.NewChallenge(r.Context(), input.Device)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusCreated, result)
}
func (s *Server) pollQRChallenge(w http.ResponseWriter, r *http.Request) {
	if s.identity == nil {
		writeError(w, identity.ErrUnauthenticated)
		return
	}
	host, _, _ := net.SplitHostPort(r.RemoteAddr)
	if !s.identity.AllowAttemptLimit("qr-poll:"+host, 120) {
		w.Header().Set("Retry-After", "60")
		writeError(w, identity.ErrRateLimited)
		return
	}
	var input struct {
		PollToken string `json:"pollToken"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.identity.PollChallenge(r.Context(), r.PathValue("id"), input.PollToken)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, result)
}
func (s *Server) inspectQRChallenge(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	var input struct {
		ApprovalCode string `json:"approvalCode"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	result, err := s.identity.InspectChallenge(r.Context(), value.User, r.PathValue("id"), input.ApprovalCode)
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, result)
}
func (s *Server) approveQRChallenge(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	var input struct {
		ApprovalCode string `json:"approvalCode"`
		Decision     string `json:"decision"`
	}
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	value := r.Context().Value(principalKey{}).(principal)
	if err := s.identity.ApproveChallenge(r.Context(), value.User, r.PathValue("id"), input.ApprovalCode, input.Decision); err != nil {
		writeError(w, err)
		return
	}
	status := "approved"
	if input.Decision == "reject" {
		status = "rejected"
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": status})
}
