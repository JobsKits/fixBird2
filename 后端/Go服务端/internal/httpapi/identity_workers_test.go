package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"image"
	"image/png"
	"mime/multipart"
	"net/http/httptest"
	"testing"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

func TestSessionPrivateApplicationHTTP(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewMemory()
	repo.EnforceWorkerApproval()
	accounts, _ := identity.NewService(identity.NewMemory(), time.Hour)
	if err := accounts.BootstrapAdmin(ctx, "http-admin", "test-admin-password"); err != nil {
		t.Fatal(err)
	}
	onboarding, err := workers.NewService(workers.NewMemory(repo.UpsertWorker), t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	marketplace := service.NewMarketplace(repo, true)
	marketplace.SetWorkerGate(onboarding)
	api := New(marketplace, t.TempDir())
	api.EnableIdentity(accounts, onboarding, true)
	handler := api.Handler()
	call := func(method, path, token string, body any) *httptest.ResponseRecorder {
		var payload bytes.Buffer
		if body != nil {
			if err := json.NewEncoder(&payload).Encode(body); err != nil {
				t.Fatal(err)
			}
		}
		r := httptest.NewRequest(method, path, &payload)
		r.Header.Set("Content-Type", "application/json")
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	// Keep KDF fixture preparation outside HTTP deadlines; real HTTP login is covered by smoke validation.
	admin, err := accounts.Login(ctx, identity.LoginInput{Username: "http-admin", Password: "test-admin-password", Device: identity.Device{Kind: "desktop"}})
	if err != nil {
		t.Fatal("prepare administrator session", err)
	}
	worker, err := accounts.Register(ctx, identity.RegisterInput{Username: "http-worker", Password: "test-worker-password", DisplayName: "测试师傅", Role: domain.RoleWorker, Device: identity.Device{Kind: "mobile"}})
	if err != nil {
		t.Fatal("prepare worker session", err)
	}
	spoof := httptest.NewRequest("GET", "/api/v1/admin/worker-applications", nil)
	spoof.Header.Set("X-Actor-Role", "admin")
	spoof.Header.Set("X-Actor-ID", "admin-demo")
	result := httptest.NewRecorder()
	handler.ServeHTTP(result, spoof)
	if result.Code != 401 {
		t.Fatal("admin header forgery", result.Code)
	}
	spoof = httptest.NewRequest("POST", "/api/v1/orders", bytes.NewBufferString(`{"category":"家电维修","equipment":"测试","issue":"测试","address":"测试"}`))
	spoof.Header.Set("Authorization", "Bearer "+worker.Token)
	spoof.Header.Set("X-Actor-Role", "customer")
	result = httptest.NewRecorder()
	handler.ServeHTTP(result, spoof)
	if result.Code != 403 {
		t.Fatal("Bearer role changed by header", result.Code)
	}
	if response := call("GET", "/api/v1/orders", worker.Token, nil); response.Code != 200 || response.Body.String() != "[]\n" {
		t.Fatal("unapproved order listing", response.Code)
	}
	var upload bytes.Buffer
	writer := multipart.NewWriter(&upload)
	part, _ := writer.CreateFormFile("file", "test.png")
	_ = png.Encode(part, image.NewRGBA(image.Rect(0, 0, 2, 2)))
	_ = writer.Close()
	r := httptest.NewRequest("POST", "/api/v1/worker-assets", &upload)
	r.Header.Set("Content-Type", writer.FormDataContentType())
	r.Header.Set("Authorization", "Bearer "+worker.Token)
	result = httptest.NewRecorder()
	handler.ServeHTTP(result, r)
	var asset workers.Asset
	if result.Code != 201 || json.Unmarshal(result.Body.Bytes(), &asset) != nil {
		t.Fatal("upload", result.Code, result.Body.String())
	}
	if response := call("GET", "/api/v1/worker-assets/"+asset.ID, "", nil); response.Code != 401 {
		t.Fatal("anonymous asset view", response.Code)
	}
	if response := call("GET", "/api/v1/worker-assets/"+asset.ID, worker.Token, nil); response.Code != 200 || response.Header().Get("Content-Type") != "image/png" || response.Header().Get("Cache-Control") != "private, no-store" {
		t.Fatal("private image response", response.Code)
	}
	input := workers.SubmitInput{DisplayName: "测试师傅", ContactPhone: "测试联系方式", ServiceAreas: []string{"测试城区"}, Skills: []string{"家电维修"}, AssetIDs: []string{asset.ID}}
	response := call("POST", "/api/v1/workers/me/application", worker.Token, input)
	var application workers.Application
	if response.Code != 200 || json.Unmarshal(response.Body.Bytes(), &application) != nil || application.Status != "pending" {
		t.Fatal("submit application", response.Code)
	}
	review := workers.ReviewInput{Decision: "approved", ExpectedRevision: 1}
	if response := call("POST", "/api/v1/admin/worker-applications/"+application.ID+"/review", worker.Token, review); response.Code != 403 {
		t.Fatal("worker self approval", response.Code)
	}
	if response := call("POST", "/api/v1/admin/worker-applications/"+application.ID+"/review", admin.Token, review); response.Code != 200 {
		t.Fatal("review", response.Code, response.Body.String())
	}
	if response := call("GET", "/api/v1/orders", worker.Token, nil); response.Code != 200 {
		t.Fatal("approved listing", response.Code)
	}
	input.ExpectedRevision = 1
	if response := call("POST", "/api/v1/workers/me/application", worker.Token, input); response.Code != 200 {
		t.Fatal("resubmit", response.Code)
	}
	if response := call("GET", "/api/v1/orders", worker.Token, nil); response.Code != 200 || response.Body.String() != "[]\n" {
		t.Fatal("resubmission exposed pending pool", response.Code)
	}
	if response := call("GET", "/api/v1/admin/worker-applications?status=pending&limit=1", admin.Token, nil); response.Code != 200 {
		t.Fatal("application filter", response.Code)
	}
	now := time.Now().UTC().Truncate(time.Millisecond)
	if _, _, err := repo.CreateOrder(ctx, domain.Order{ID: "ord_registered_private", CustomerID: "usr_registered_customer", Category: "家电维修", Equipment: "测试", Issue: "测试", Address: "应隔离的测试地址", Status: domain.StatusPendingWorker, PaymentStatus: domain.PaymentNotStarted, CreatedAt: now, UpdatedAt: now}, "", ""); err != nil {
		t.Fatal(err)
	}
	r = httptest.NewRequest("GET", "/api/v1/orders", nil)
	r.Header.Set("X-Actor-Role", "worker")
	result = httptest.NewRecorder()
	handler.ServeHTTP(result, r)
	if result.Code != 200 || result.Body.String() != "[]\n" {
		t.Fatal("anonymous worker exposed registered customer's pending pool", result.Code, result.Body.String())
	}
	r = httptest.NewRequest("POST", "/api/v1/orders/ord_registered_private/accept", nil)
	r.Header.Set("X-Actor-Role", "worker")
	result = httptest.NewRecorder()
	handler.ServeHTTP(result, r)
	if result.Code != 403 {
		t.Fatal("anonymous demo worker accepted registered order", result.Code)
	}
	if response := call("POST", "/api/v1/auth/logout", worker.Token, nil); response.Code != 204 {
		t.Fatal("logout", response.Code)
	}
	if response := call("GET", "/api/v1/auth/me", worker.Token, nil); response.Code != 401 {
		t.Fatal("revoked token fallback", response.Code)
	}
}
