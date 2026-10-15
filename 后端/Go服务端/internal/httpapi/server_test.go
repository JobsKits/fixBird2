package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
)

const orderBody = `{"category":"家电维修","equipment":"冰箱","issue":"不制冷","address":"测试地址","scheduledAt":""}`

func request(handler http.Handler, method, path, role, body, key string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("X-Actor-Role", role)
	if key != "" {
		r.Header.Set("Idempotency-Key", key)
	}
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, r)
	return w
}

func TestStrictJSONAndMachineErrors(t *testing.T) {
	h := New(service.NewMarketplace(repository.NewMemory(), true), t.TempDir()).Handler()
	for _, body := range []string{orderBody + ` {}`, strings.TrimSuffix(orderBody, "}") + `,"unknown":1}`, "null", "{"} {
		w := request(h, "POST", "/api/v1/orders", "customer", body, "")
		if w.Code != 400 || !strings.Contains(w.Body.String(), `"code":"invalid_input"`) {
			t.Fatal(w.Code, w.Body.String())
		}
	}
	w := request(h, "POST", "/api/v1/orders", "customer", orderBody+strings.Repeat(" ", int(MaxJSONBytes)), "")
	if w.Code != 413 || !strings.Contains(w.Body.String(), "body_too_large") {
		t.Fatal(w.Code, w.Body.String())
	}
	w = request(h, "POST", "/api/v1/orders", "customer", orderBody, "same-key")
	var first domain.Order
	if w.Code != 201 || json.Unmarshal(w.Body.Bytes(), &first) != nil {
		t.Fatal(w.Code, w.Body.String())
	}
	w = request(h, "POST", "/api/v1/orders", "customer", orderBody, "same-key")
	var second domain.Order
	if w.Code != 201 || json.Unmarshal(w.Body.Bytes(), &second) != nil || first.ID != second.ID {
		t.Fatal("HTTP retry created a duplicate", w.Body.String())
	}
	w = request(h, "POST", "/api/v1/orders", "customer", strings.Replace(orderBody, "不制冷", "different", 1), "same-key")
	if w.Code != 409 || !strings.Contains(w.Body.String(), "idempotency_conflict") {
		t.Fatal(w.Code, w.Body.String())
	}
	for _, path := range []string{"/api/v1/orders?limit=0", "/api/v1/orders?limit=201", "/api/v1/orders?cursor=bad", "/api/v1/orders?status=invalid"} {
		if w := request(h, "GET", path, "customer", "", ""); w.Code != 400 {
			t.Fatal(path, w.Code)
		}
	}
	if w.Header().Get("X-Request-ID") == "" {
		t.Fatal("missing request id")
	}
}

func TestArrayPagingAndIndependentAdminQueries(t *testing.T) {
	m := service.NewMarketplace(repository.NewMemory(), true)
	h := New(m, t.TempDir()).Handler()
	for i := 0; i < 3; i++ {
		if w := request(h, "POST", "/api/v1/orders", "customer", orderBody, ""); w.Code != 201 {
			t.Fatal(w.Code)
		}
	}
	w := request(h, "GET", "/api/v1/orders?limit=1", "customer", "", "")
	var page []domain.Order
	if w.Code != 200 || json.Unmarshal(w.Body.Bytes(), &page) != nil || len(page) != 1 || w.Header().Get("X-Next-Cursor") == "" {
		t.Fatal(w.Body.String())
	}
	w2 := request(h, "GET", "/api/v1/orders?limit=1&cursor="+w.Header().Get("X-Next-Cursor"), "customer", "", "")
	var next []domain.Order
	if json.Unmarshal(w2.Body.Bytes(), &next) != nil || len(next) != 1 || next[0].ID == page[0].ID {
		t.Fatal("cursor repeated first row", w2.Body.String())
	}
	broken := failingOrders{Repository: repository.NewMemory()}
	accounts, _ := identity.NewService(identity.NewMemory(), time.Hour)
	if err := accounts.BootstrapAdmin(context.Background(), "independent-admin", "test-admin-password"); err != nil {
		t.Fatal(err)
	}
	auth, err := accounts.Login(context.Background(), identity.LoginInput{Username: "independent-admin", Password: "test-admin-password"})
	if err != nil {
		t.Fatal(err)
	}
	api := New(service.NewMarketplace(broken, true), t.TempDir())
	api.EnableIdentity(accounts, nil, true)
	h = api.Handler()
	for _, path := range []string{"/api/v1/admin/workers", "/api/v1/admin/settlements"} {
		r := httptest.NewRequest("GET", path, nil)
		r.Header.Set("Authorization", "Bearer "+auth.Token)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != 200 {
			t.Fatal("admin endpoint depends on orders", path, w.Code)
		}
	}
}

type failingOrders struct{ repository.Repository }

func (failingOrders) ListOrders(context.Context, domain.ListQuery) ([]domain.Order, error) {
	return nil, errors.New("simulated orders failure")
}

type failingReady struct{ repository.Repository }

func (failingReady) Ready(ctx context.Context) error { <-ctx.Done(); return ctx.Err() }

func TestLivenessIsSeparateFromReadiness(t *testing.T) {
	h := New(service.NewMarketplace(failingReady{repository.NewMemory()}, true), t.TempDir()).Handler()
	if w := request(h, "GET", "/healthz", "", "", ""); w.Code != 200 {
		t.Fatal(w.Code)
	}
	started := time.Now()
	if w := request(h, "GET", "/readyz", "", "", ""); w.Code != 503 {
		t.Fatal(w.Code)
	}
	if elapsed := time.Since(started); elapsed > 3*time.Second {
		t.Fatal("readiness timeout did not bound dependency", elapsed)
	}
}
