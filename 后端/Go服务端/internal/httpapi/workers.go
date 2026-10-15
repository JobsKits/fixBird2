package httpapi

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net/http"

	"repair-platform/internal/domain"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

func (s *Server) registerWorkerRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/workers/me/application", s.workerApplication)
	mux.HandleFunc("POST /api/v1/workers/me/application", s.submitWorkerApplication)
	mux.HandleFunc("POST /api/v1/worker-assets", s.uploadWorkerAsset)
	mux.HandleFunc("GET /api/v1/worker-assets/{id}", s.readWorkerAsset)
	mux.HandleFunc("GET /api/v1/admin/worker-applications", s.adminApplications)
	mux.HandleFunc("POST /api/v1/admin/worker-applications/{id}/review", s.reviewWorkerApplication)
}

func (s *Server) workerApplication(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if s.workers == nil {
		writeError(w, service.ErrForbidden)
		return
	}
	application, err := s.workers.Get(r.Context(), actorFrom(r))
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, application)
}
func (s *Server) submitWorkerApplication(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if s.workers == nil {
		writeError(w, service.ErrForbidden)
		return
	}
	var input workers.SubmitInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	application, err := s.workers.Submit(r.Context(), actorFrom(r), input)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, application)
}
func (s *Server) adminApplications(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) {
		return
	}
	if s.workers == nil {
		writeError(w, service.ErrForbidden)
		return
	}
	// Reuse the bounded cursor parser while leaving application status validation to its service.
	copy := r.Clone(r.Context())
	url := *r.URL
	copy.URL = &url
	values := url.Query()
	status := values.Get("status")
	values.Del("status")
	copy.URL.RawQuery = values.Encode()
	query, err := parseListQuery(copy, false)
	if err != nil {
		writeError(w, err)
		return
	}
	applications, err := s.workers.List(r.Context(), actorFrom(r), workers.ListQuery{Limit: query.PageSize(), Before: query.Before, Status: status})
	if err != nil {
		writeError(w, err)
		return
	}
	if len(applications) > query.PageSize() {
		applications = applications[:query.PageSize()]
		last := applications[len(applications)-1]
		setCursor(w, domain.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, applications)
}
func (s *Server) reviewWorkerApplication(w http.ResponseWriter, r *http.Request) {
	if !requireSessionAdmin(w, r) {
		return
	}
	if s.workers == nil {
		writeError(w, service.ErrForbidden)
		return
	}
	var input workers.ReviewInput
	if err := decodeJSON(w, r, &input); err != nil {
		writeError(w, err)
		return
	}
	application, err := s.workers.Review(r.Context(), actorFrom(r), r.PathValue("id"), input)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, application)
}
func (s *Server) uploadWorkerAsset(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if s.workers == nil || actorFrom(r).Role != domain.RoleWorker {
		writeError(w, service.ErrForbidden)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, workers.MaxImageBytes+(64<<10))
	defer r.Body.Close()
	reader, err := r.MultipartReader()
	if err != nil {
		writeError(w, fmt.Errorf("%w: multipart file is required", service.ErrInvalidInput))
		return
	}
	part, err := reader.NextPart()
	if err != nil {
		writeError(w, service.ErrInvalidInput)
		return
	}
	if part.FormName() != "file" || part.FileName() == "" {
		writeError(w, service.ErrInvalidInput)
		return
	}
	payload, err := io.ReadAll(io.LimitReader(part, workers.MaxImageBytes+1))
	_ = part.Close()
	var oversized *http.MaxBytesError
	if errors.As(err, &oversized) || int64(len(payload)) > workers.MaxImageBytes {
		writeError(w, workers.ErrImageTooLarge)
		return
	}
	if err != nil {
		writeError(w, classifyJSONError(err))
		return
	}
	if _, err := reader.NextPart(); err != io.EOF {
		if errors.As(err, &oversized) {
			writeError(w, workers.ErrImageTooLarge)
		} else {
			writeError(w, service.ErrInvalidInput)
		}
		return
	}
	asset, err := s.workers.Upload(r.Context(), actorFrom(r), bytes.NewReader(payload))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, asset)
}
func (s *Server) readWorkerAsset(w http.ResponseWriter, r *http.Request) {
	if !requireSession(w, r) {
		return
	}
	if s.workers == nil {
		writeError(w, service.ErrForbidden)
		return
	}
	asset, payload, err := s.workers.ReadAsset(r.Context(), actorFrom(r), r.PathValue("id"))
	if err != nil {
		writeError(w, err)
		return
	}
	w.Header().Set("Content-Type", asset.MIMEType)
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("Content-Disposition", `inline; filename="qualification-image"`)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(payload)
}
