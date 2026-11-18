package workbench

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func directoryWrite(t *testing.T, s *Service, actor Actor, input customerDirectoryInput, key string) (map[string]any, error) {
	t.Helper()
	raw, _ := json.Marshal(input)
	body, _, err := s.transact(actor, "POST /api/v38/customer-directory", key, raw, 201, func(state *State) (any, error) {
		return s.mutateCustomerDirectory(state, actor, input)
	})
	var out map[string]any
	if err == nil {
		err = json.Unmarshal(body, &out)
	}
	return out, err
}

func TestCustomerDirectoryAuthorizedRelationsAndPersistence(t *testing.T) {
	s, persistence := testService(t)
	admin := testActor(s, "admin")
	seed := customerDirectoryView(&s.state, admin)
	if len(seed["customers"].([]map[string]any)) != 2 {
		t.Fatal("legacy customer contacts should group by their existing company")
	}
	const password = "NewCustomerPassword!"
	input := customerDirectoryInput{Operation: "customer", Name: "新客户档案", CompanyName: "第一企业", Username: "new_customer", Password: password, ConfirmPassword: password}
	out, err := directoryWrite(t, s, admin, input, "directory-create")
	if err != nil {
		t.Fatal(err)
	}
	customerID, accountID, companyID := out["customerId"].(string), out["accountId"].(string), out["companyId"].(string)
	replay, err := directoryWrite(t, s, admin, input, "directory-create")
	if err != nil || replay["accountId"] != accountID || len(s.state.Accounts) != 12 {
		t.Fatal("same intent must not duplicate a customer login", err)
	}
	_, actor, err := s.login("new_customer", password, "directory-fixture")
	if err != nil || actor.Role != "customer" || actor.ID != accountID || actor.CompanyID != companyID {
		t.Fatal("new customer account must have real scoped credentials", err)
	}
	out, err = directoryWrite(t, s, admin, customerDirectoryInput{Operation: "company", CustomerID: customerID, Name: "第二企业"}, "second-company")
	if err != nil {
		t.Fatal(err)
	}
	secondCompany := out["companyId"].(string)
	out, err = directoryWrite(t, s, testActor(s, "dispatcher"), customerDirectoryInput{Operation: "account", CustomerID: customerID, CompanyID: secondCompany, Username: "new_customer_two", Password: password, ConfirmPassword: password}, "second-account")
	if err != nil {
		t.Fatal(err)
	}
	if len(s.state.Customers[len(s.state.Customers)-1].Companies) != 2 || len(s.state.Customers[len(s.state.Customers)-1].AccountIDs) != 2 {
		t.Fatal("customer group must retain multiple accounts and companies")
	}
	if _, err := directoryWrite(t, s, actor, customerDirectoryInput{Operation: "company", CustomerID: customerID, Name: "越权企业"}, "denied-company"); err == nil {
		t.Fatal("customer must not create directory identities")
	}
	if _, err := directoryWrite(t, s, admin, customerDirectoryInput{Operation: "account", CustomerID: customerID, CompanyID: "company-a", Username: "cross_company", Password: password, ConfirmPassword: password}, "denied-account"); err == nil {
		t.Fatal("account must not bind a company outside its customer profile")
	}
	view := customerDirectoryView(&s.state, actor)
	raw, _ := json.Marshal(view)
	if strings.Contains(string(raw), "new_customer_two") || strings.Contains(string(raw), password) || strings.Contains(string(raw), "\"hash\"") || strings.Contains(string(raw), "company-a") {
		t.Fatal("customer projection leaked another account or credentials")
	}
	restarted, err := New(persistence)
	if err != nil || len(restarted.state.Customers) != 3 || validateCustomerDirectory(restarted.state) != nil {
		t.Fatal("directory relations did not survive restart", err)
	}
}

func TestCustomerDirectoryHTTPPermissionsAndAtomicFailure(t *testing.T) {
	s, persistence := testService(t)
	token, _, err := s.login("customer", "Demo-Repair-2026!", "directory-http")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "/api/v38/customer-directory", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(response, request)
	if response.Code != 200 || strings.Contains(response.Body.String(), "customer-peer") || strings.Contains(response.Body.String(), "company-b") {
		t.Fatal("directory route failed scoped customer projection", response.Code)
	}
	before := len(s.state.Accounts)
	persistence.fail = true
	_, err = directoryWrite(t, s, testActor(s, "admin"), customerDirectoryInput{Operation: "customer", Name: "不得半写", CompanyName: "不得半写", Username: "must_rollback", Password: "ValidPassword!", ConfirmPassword: "ValidPassword!"}, "rollback-customer")
	if err == nil || len(s.state.Accounts) != before || len(s.state.Customers) != 0 {
		t.Fatal("directory partial state escaped a failed snapshot save")
	}
}
