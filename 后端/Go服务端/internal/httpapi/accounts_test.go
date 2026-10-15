package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"strings"
	"testing"
	"time"
)

func TestAccountPermissionsAndRevocationHTTP(t *testing.T) {
	ctx := context.Background()
	accounts, err := identity.NewService(identity.NewMemory(), time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if err := accounts.BootstrapAdmin(ctx, "", ""); err != nil {
		t.Fatal(err)
	}
	admin, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "admin"})
	if err != nil {
		t.Fatal("default administrator", err)
	}
	api := New(service.NewMarketplace(repository.NewMemory(), true), t.TempDir())
	api.EnableIdentity(accounts, nil, true)
	// Race instrumentation slows the password KDF. Exercise real authentication/handlers
	// without the unrelated production deadline; live HTTP smoke keeps that deadline.
	mux := http.NewServeMux()
	api.registerIdentityRoutes(mux)
	mux.HandleFunc("GET /api/v1/admin/dashboard", api.adminDashboard)
	mux.HandleFunc("GET /api/v1/admin/worker-applications", api.adminApplications)
	handler := api.withIdentity(mux)
	call := func(method, path, token string, body any) *httptest.ResponseRecorder {
		var payload bytes.Buffer
		if body != nil {
			if err := json.NewEncoder(&payload).Encode(body); err != nil {
				t.Fatal(err)
			}
		}
		req := httptest.NewRequest(method, path, &payload)
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		out := httptest.NewRecorder()
		handler.ServeHTTP(out, req)
		return out
	}
	expect := func(out *httptest.ResponseRecorder, code int) {
		t.Helper()
		if out.Code != code {
			t.Fatalf("HTTP %d want %d: %s", out.Code, code, out.Body.String())
		}
	}
	expect(call("GET", "/api/v1/admin/accounts", "", nil), 401)
	expect(call("POST", "/api/v1/auth/admin-applications", "", map[string]string{}), 404)
	result := call("POST", "/api/v1/admin/accounts", admin.Token, identity.AccountInput{Username: "operator-one", Password: "initial-password-long", DisplayName: "普通账号", Role: domain.RoleOperator})
	expect(result, 201)
	if strings.Contains(result.Body.String(), "passwordHash") || strings.Contains(result.Body.String(), "pbkdf2") {
		t.Fatal("password hash disclosed")
	}
	var created identity.AccountResult
	if err := json.Unmarshal(result.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	op, err := accounts.Login(ctx, identity.LoginInput{Username: "operator-one", Password: "initial-password-long"})
	if err != nil {
		t.Fatal(err)
	}
	expect(call("GET", "/api/v1/admin/dashboard", op.Token, nil), 200)
	for _, path := range []string{"/api/v1/admin/accounts", "/api/v1/admin/worker-applications"} {
		expect(call("GET", path, op.Token, nil), 403)
	}
	expect(call("POST", "/api/v1/admin/accounts", op.Token, identity.AccountInput{Username: "forged", Password: "initial-password-long", DisplayName: "越权", Role: domain.RoleAdmin}), 403)
	expect(call("POST", "/api/v1/admin/accounts/admin/password", op.Token, map[string]string{"password": "forged-password-long"}), 403)
	expect(call("POST", "/api/v1/admin/accounts/admin/status", op.Token, map[string]string{"status": "disabled"}), 403)
	expect(call("POST", "/api/v1/auth/password", op.Token, map[string]string{"currentPassword": "initial-password-long", "password": "own-password-changed"}), 204)
	expect(call("GET", "/api/v1/auth/me", op.Token, nil), 401)
	op, err = accounts.Login(ctx, identity.LoginInput{Username: "operator-one", Password: "own-password-changed"})
	if err != nil {
		t.Fatal(err)
	}
	expect(call("POST", "/api/v1/admin/accounts/operator-one/status", admin.Token, map[string]string{"status": "disabled"}), 204)
	expect(call("GET", "/api/v1/auth/me", op.Token, nil), 401)
	if _, err := accounts.Login(ctx, identity.LoginInput{Username: "operator-one", Password: "own-password-changed"}); err != identity.ErrAccountDisabled {
		t.Fatal("disabled login accepted", err)
	}
	expect(call("POST", "/api/v1/admin/accounts/operator-one/status", admin.Token, map[string]string{"status": "active"}), 204)
	expect(call("GET", "/api/v1/auth/me", op.Token, nil), 401)
	op, err = accounts.Login(ctx, identity.LoginInput{Username: "operator-one", Password: "own-password-changed"})
	if err != nil {
		t.Fatal(err)
	}
	recovery, err := accounts.NewRecoveryCode(ctx, op.User)
	if err != nil {
		t.Fatal(err)
	}
	expect(call("POST", "/api/v1/auth/password-reset", "", identity.PasswordResetInput{Username: "operator-one", RecoveryCode: recovery, Password: "recovered-password-long"}), 204)
	expect(call("GET", "/api/v1/auth/me", op.Token, nil), 401)
	expect(call("POST", "/api/v1/auth/password-reset", "", identity.PasswordResetInput{Username: "operator-one", RecoveryCode: recovery, Password: "replayed-password-long"}), 401)
	customer, err := accounts.Register(ctx, identity.RegisterInput{Username: "customer-one", Password: "customer-password-long", DisplayName: "移动用户", Role: domain.RoleCustomer})
	if err != nil {
		t.Fatal(err)
	}
	expect(call("POST", "/api/v1/admin/accounts/customer-one/password", admin.Token, map[string]string{"password": "customer-reset-long"}), 204)
	expect(call("GET", "/api/v1/auth/me", customer.Token, nil), 401)
	if _, err := accounts.Login(ctx, identity.LoginInput{Username: "customer-one", Password: "customer-reset-long"}); err != nil {
		t.Fatal("admin did not reset mobile account", err)
	}
	expect(call("POST", "/api/v1/admin/accounts", admin.Token, identity.AccountInput{Username: "admin-two", Password: "another-admin-password", DisplayName: "另一个管理员", Role: domain.RoleAdmin}), 201)
	other, err := accounts.Login(ctx, identity.LoginInput{Username: "admin-two", Password: "another-admin-password"})
	if err != nil {
		t.Fatal(err)
	}
	expect(call("GET", "/api/v1/admin/accounts", other.Token, nil), 200)
	expect(call("POST", "/api/v1/admin/accounts/admin-two/status", other.Token, map[string]string{"status": "disabled"}), 400)
	expect(call("POST", "/api/v1/auth/password", admin.Token, map[string]string{"currentPassword": "admin", "password": "primary-password-changed"}), 204)
	if err := accounts.BootstrapAdmin(ctx, "", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "admin"}); err == nil {
		t.Fatal("deployment reset existing administrator password")
	}
	if _, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "primary-password-changed"}); err != nil {
		t.Fatal(err)
	}
}
