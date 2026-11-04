package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestClientRoutes(t *testing.T) {
	admin := t.TempDir()
	if err := os.WriteFile(filepath.Join(admin, "index.html"), []byte("new-admin"), 0600); err != nil {
		t.Fatal(err)
	}
	h := clientHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(418)
	}), admin, t.TempDir(), t.TempDir(), t.TempDir())
	for _, tc := range []struct {
		path   string
		status int
	}{
		{"/admin/", 200}, {"/admin", http.StatusTemporaryRedirect}, {"/api/v38/orders", 418},
		{"/admin/secret.key", 404}, {"/admin-contract/storage.key", 404},
		{"/admin-flutter/", 503}, {"/client-flutter/", 503},
	} {
		r := httptest.NewRecorder()
		h.ServeHTTP(r, httptest.NewRequest("GET", tc.path, nil))
		if r.Code != tc.status {
			t.Errorf("%s: got %d, want %d", tc.path, r.Code, tc.status)
		}
		if r.Header().Get("X-Content-Type-Options") != "nosniff" {
			t.Fatal("missing content protection")
		}
	}
}
