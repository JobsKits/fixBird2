package workbench

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

func publicAuthRequest(t *testing.T, s *Service, endpoint string, input any, host, remote string) (int, map[string]any) {
	t.Helper()
	raw, err := json.Marshal(input)
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest("POST", "http://"+host+"/api/v38/"+endpoint, bytes.NewReader(raw))
	r.RemoteAddr = remote
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	var out map[string]any
	if err = json.Unmarshal(w.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	return w.Code, out
}

func authFixtureCode(t *testing.T, s *Service, email, purpose string) string {
	t.Helper()
	status, out := publicAuthRequest(t, s, "auth/email-code", map[string]string{"email": email, "purpose": purpose}, "localhost:8098", "127.0.0.1:3010")
	if status != 200 || out["delivery"] != "demo" || len(fmt.Sprint(out["demoCode"])) != 6 {
		t.Fatalf("local demo code: status=%d response=%v", status, out)
	}
	return out["demoCode"].(string)
}

func authFixtureBody(email, username, code, password string) map[string]string {
	return map[string]string{"email": email, "username": username, "name": "合成注册客户", "code": code, "password": password, "confirmPassword": password}
}

func TestPublicAuthRegistrationResetAndIsolation(t *testing.T) {
	t.Setenv("WB_SMTP_HOST", "")
	s, p := testService(t)
	email := "alice@example.test"
	code := authFixtureCode(t, s, email, "register")
	body := authFixtureBody(email, "alice-fixture", code, "First-Password!8")
	for _, field := range []string{"role", "companyId", "authVersion"} {
		privileged := map[string]string{}
		for k, v := range body {
			privileged[k] = v
		}
		privileged[field] = "admin"
		if status, _ := publicAuthRequest(t, s, "register", privileged, "localhost", "127.0.0.1:3010"); status != 422 {
			t.Fatalf("privileged field %s accepted: %d", field, status)
		}
	}
	status, out := publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010")
	if status != 201 {
		t.Fatalf("register: %d %v", status, out)
	}
	actor := out["actor"].(map[string]any)
	if actor["role"] != "customer" || actor["companyId"] == "company-a" || actor["authVersion"] != float64(1) || out["token"] != nil {
		t.Fatalf("unsafe registration projection: %v", out)
	}
	token, alice, err := s.login(email, body["password"], "auth-fixture")
	if err != nil || alice.ID != actor["id"] {
		t.Fatalf("new email login failed: %v", err)
	}
	if status, _ = publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010"); status != 422 {
		t.Fatal("used verification code remained usable")
	}
	otherCode := authFixtureCode(t, s, "bob@example.test", "register")
	status, other := publicAuthRequest(t, s, "register", authFixtureBody("bob@example.test", "bob-fixture", otherCode, "Second-Password!8"), "localhost", "127.0.0.1:3010")
	if status != 201 || actor["companyId"] == other["actor"].(map[string]any)["companyId"] {
		t.Fatal("new public customers were put in a shared company")
	}
	otherActor := testActor(s, other["actor"].(map[string]any)["id"].(string))
	created, err := s.createOrder(&s.state, alice, CreateOrderInput{Type: "mail", Device: "合成设备", Description: "合成隔离测试需求"})
	if err != nil || visible(created, otherActor) || !visible(created, alice) || visible(testOrder(t, s, "wo_intake"), alice) {
		t.Fatalf("customer company isolation failed: %v", err)
	}
	resetCode := authFixtureCode(t, s, email, "reset_password")
	reset := map[string]string{"email": email, "code": resetCode, "password": "Changed-Password!8", "confirmPassword": "Changed-Password!8"}
	status, out = publicAuthRequest(t, s, "reset-password", reset, "localhost", "127.0.0.1:3010")
	if status != 200 || out["token"] != nil {
		t.Fatalf("reset: %d %v", status, out)
	}
	if _, err = s.authenticate(token); err == nil {
		t.Fatal("old session survived password reset")
	}
	if _, _, err = s.login("alice-fixture", body["password"], "old-password"); err == nil {
		t.Fatal("old password survived reset")
	}
	if _, current, err := s.login(email, reset["password"], "new-password"); err != nil || current.AuthVersion != 2 {
		t.Fatalf("new password/authVersion failed: %v", err)
	}
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err = restarted.login(email, reset["password"], "restart"); err != nil {
		t.Fatalf("reset credentials not persisted: %v", err)
	}
}

func TestPublicAuthCodeBoundsAndDelivery(t *testing.T) {
	t.Setenv("WB_SMTP_HOST", "")
	for _, tc := range []struct {
		name, host, remote string
		demo               bool
	}{
		{"production", "localhost", "127.0.0.1:3010", false},
		{"remote-connection", "localhost", "203.0.113.8:3010", true},
		{"remote-host", "example.test", "127.0.0.1:3010", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := testService(t)
			s.state.Settings.Demo = tc.demo
			status, out := publicAuthRequest(t, s, "auth/email-code", map[string]string{"email": "delivery@example.test", "purpose": "register"}, tc.host, tc.remote)
			if status != 503 || out["demoCode"] != nil || out["ok"] != nil || len(s.authCodes) != 0 {
				t.Fatalf("mail falsely sent or code disclosed: %d %v", status, out)
			}
		})
	}
	s, _ := testService(t)
	now := time.Date(2026, 11, 18, 9, 0, 0, 0, time.UTC)
	s.now = func() time.Time { return now }
	code := authFixtureCode(t, s, "attempts@example.test", "register")
	if status, _ := publicAuthRequest(t, s, "auth/email-code", map[string]string{"email": "attempts@example.test", "purpose": "register"}, "localhost", "127.0.0.1:3010"); status != 429 {
		t.Fatal("resend was not rate limited")
	}
	for i := 0; i < 5; i++ {
		wrong := "000000"
		if code == wrong {
			wrong = "111111"
		}
		status, _ := publicAuthRequest(t, s, "register", authFixtureBody("attempts@example.test", "attempt-fixture", wrong, "Test-Password!8"), "localhost", "127.0.0.1:3010")
		if status != 422 {
			t.Fatal("bad code was accepted")
		}
	}
	if status, _ := publicAuthRequest(t, s, "register", authFixtureBody("attempts@example.test", "attempt-fixture", code, "Test-Password!8"), "localhost", "127.0.0.1:3010"); status != 422 {
		t.Fatal("attempt-exhausted code was accepted")
	}
	expired := authFixtureCode(t, s, "expired@example.test", "register")
	now = now.Add(11 * time.Minute)
	if status, _ := publicAuthRequest(t, s, "register", authFixtureBody("expired@example.test", "expired-fixture", expired, "Test-Password!8"), "localhost", "127.0.0.1:3010"); status != 422 {
		t.Fatal("expired code was accepted")
	}
	for i := 0; i < 20; i++ {
		authFixtureCode(t, s, fmt.Sprintf("rate%d@example.test", i), "register")
	}
	if status, _ := publicAuthRequest(t, s, "auth/email-code", map[string]string{"email": "over-limit@example.test", "purpose": "register"}, "localhost", "127.0.0.1:3010"); status != 429 {
		t.Fatal("per-source rate limit was not enforced")
	}
}

func TestPublicAuthPersistenceFailureAndSingleUseConcurrency(t *testing.T) {
	t.Setenv("WB_SMTP_HOST", "")
	s, p := testService(t)
	code := authFixtureCode(t, s, "atomic@example.test", "register")
	body := authFixtureBody("atomic@example.test", "atomic-fixture", code, "Atomic-Password!8")
	before := len(s.state.Accounts)
	p.fail = true
	if status, _ := publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010"); status != 500 || len(s.state.Accounts) != before {
		t.Fatal("failed save committed an account")
	}
	p.fail = false
	var wg sync.WaitGroup
	statuses := make(chan int, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			status, _ := publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010")
			statuses <- status
		}()
	}
	wg.Wait()
	close(statuses)
	winners := 0
	for status := range statuses {
		if status == 201 {
			winners++
		}
	}
	if winners != 1 || len(s.state.Accounts) != before+1 {
		t.Fatal("verification code was not consumed atomically")
	}
	token, _, err := s.login("atomic-fixture", body["password"], "atomic-login")
	if err != nil {
		t.Fatal(err)
	}
	resetCode := authFixtureCode(t, s, "atomic@example.test", "reset_password")
	reset := map[string]string{"email": "atomic@example.test", "code": resetCode, "password": "Changed-Atomic!8", "confirmPassword": "Changed-Atomic!8"}
	p.fail = true
	if status, _ := publicAuthRequest(t, s, "reset-password", reset, "localhost", "127.0.0.1:3010"); status != 500 {
		t.Fatal("failed reset save was accepted")
	}
	if _, err = s.authenticate(token); err != nil {
		t.Fatal("failed reset revoked current session")
	}
	p.fail = false
	if status, _ := publicAuthRequest(t, s, "reset-password", reset, "localhost", "127.0.0.1:3010"); status != 200 {
		t.Fatal("same code could not retry after failed save")
	}
}
