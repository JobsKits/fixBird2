package main

import (
	"bytes"
	"io"
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

func TestPublicUIResources(t *testing.T) {
	root := t.TempDir()
	admin := filepath.Join(root, "后台管理端", "Web")
	assets := filepath.Join(root, "共享组件", "Flutter", "assets")
	resources := []struct {
		name        string
		contentType string
		body        []byte
	}{
		{"NotoSansSC.ttf", "font/ttf", []byte("bundled simplified Chinese font")},
		{"NotoSansCJKsc-Regular.otf", "font/otf", []byte("bundled CJK font")},
		{"NotoSerifTibetan.ttf", "font/ttf", []byte("bundled Tibetan font")},
		{"ui-l10n.json", "application/json; charset=utf-8", []byte(`{"保存":["Save"]}`)},
	}
	for _, dir := range []string{admin, assets, filepath.Join(root, "共享组件", "Flutter", "lib")} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	for _, resource := range resources {
		if err := os.WriteFile(filepath.Join(assets, resource.name), resource.body, 0600); err != nil {
			t.Fatal(err)
		}
	}
	private := []byte("shared source must stay private")
	for _, path := range []string{
		filepath.Join(assets, "private.txt"),
		filepath.Join(root, "共享组件", "Flutter", "lib", "source.dart"),
	} {
		if err := os.WriteFile(path, private, 0600); err != nil {
			t.Fatal(err)
		}
	}
	server := httptest.NewServer(clientHandler(http.NotFoundHandler(), admin, t.TempDir(), t.TempDir(), t.TempDir()))
	t.Cleanup(server.Close)
	for _, resource := range resources {
		t.Run(resource.name, func(t *testing.T) {
			response, err := server.Client().Get(server.URL + "/admin-font/" + resource.name)
			if err != nil {
				t.Fatal(err)
			}
			defer response.Body.Close()
			body, err := io.ReadAll(response.Body)
			if err != nil {
				t.Fatal(err)
			}
			if response.StatusCode != http.StatusOK {
				t.Fatalf("status: got %d, want %d", response.StatusCode, http.StatusOK)
			}
			if got := response.Header.Get("Content-Type"); got != resource.contentType {
				t.Errorf("MIME: got %q, want %q", got, resource.contentType)
			}
			if !bytes.Equal(body, resource.body) {
				t.Error("served content differs from the bundled resource")
			}
			if response.Header.Get("X-Content-Type-Options") != "nosniff" {
				t.Error("missing content protection")
			}
		})
	}
	for _, path := range []string{
		"/admin-font/",
		"/admin-font/private.txt",
		"/admin-font/lib/source.dart",
		"/admin-font/../共享组件/Flutter/lib/source.dart",
		"/admin-font/%2e%2e/共享组件/Flutter/lib/source.dart",
		"/admin-font/NotoSansSC.ttf/../private.txt",
	} {
		t.Run(path, func(t *testing.T) {
			response, err := server.Client().Get(server.URL + path)
			if err != nil {
				t.Fatal(err)
			}
			defer response.Body.Close()
			body, err := io.ReadAll(response.Body)
			if err != nil {
				t.Fatal(err)
			}
			if response.StatusCode != http.StatusNotFound {
				t.Errorf("status: got %d, want %d", response.StatusCode, http.StatusNotFound)
			}
			if bytes.Contains(body, private) {
				t.Error("shared source or an unlisted asset was exposed")
			}
		})
	}
}
