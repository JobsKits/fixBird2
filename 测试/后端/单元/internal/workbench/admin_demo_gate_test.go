package workbench

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
)

func TestAdminDemoCredentialsAndEnvironmentGate(t *testing.T) {
	s, _ := testService(t)
	if _, actor, err := s.login("admin", "1234", "demo-admin"); err != nil || actor.Role != "admin" {
		t.Fatalf("Demo admin/1234 must work: actor=%+v err=%v", actor, err)
	}
	readMode := func() string {
		r := httptest.NewRecorder()
		s.Handler(t.TempDir()).ServeHTTP(r, httptest.NewRequest("GET", "/api/v38/healthz", nil))
		var result map[string]any
		if err := json.Unmarshal(r.Body.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		return result["mode"].(string)
	}
	if mode := readMode(); mode != "synthetic_demo" {
		t.Fatalf("Demo mode = %s", mode)
	}
	s.state.Settings.Demo = false
	if mode := readMode(); mode != "production" {
		t.Fatalf("production mode = %s", mode)
	}
	if _, _, err := s.login("admin", "1234", "production-admin"); err == nil {
		t.Fatal("production must not accept Demo admin/1234")
	}
	r := httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(r, httptest.NewRequest("GET", "/api/v38/bootstrap", nil))
	if r.Code != 401 {
		t.Fatalf("anonymous production bootstrap status = %d", r.Code)
	}
	s.state.Settings.Demo = true
	for i := range s.state.Accounts {
		if s.state.Accounts[i].Actor.Username == "admin" {
			s.state.Accounts[i].Actor.Status = "disabled"
		}
	}
	if _, _, err := s.login("admin", "1234", "disabled-demo-admin"); err == nil {
		t.Fatal("Demo must not revive disabled admin")
	}
}
