package workbench

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"unicode/utf8"
)

type CustomerCompany struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// A customer can own several login accounts and companies; each Actor retains
// its existing single-company authorization boundary.
type CustomerProfile struct {
	ID         string            `json:"id"`
	Name       string            `json:"name"`
	AccountIDs []string          `json:"accountIds"`
	Companies  []CustomerCompany `json:"companies"`
}

type customerDirectoryInput struct {
	Operation       string `json:"operation"`
	CustomerID      string `json:"customerId"`
	Name            string `json:"name"`
	CompanyName     string `json:"companyName"`
	CompanyID       string `json:"companyId"`
	Username        string `json:"username"`
	AccountName     string `json:"accountName"`
	Password        string `json:"password"`
	ConfirmPassword string `json:"confirmPassword"`
}

func directoryProfiles(state *State) []CustomerProfile {
	profiles := append([]CustomerProfile(nil), state.Customers...)
	known := map[string]bool{}
	for _, profile := range profiles {
		for _, id := range profile.AccountIDs {
			known[id] = true
		}
	}
	for _, account := range state.Accounts {
		actor := account.Actor
		if actor.Role != "customer" || known[actor.ID] {
			continue
		}
		group := "cust_legacy_" + actor.CompanyID
		index := -1
		for i := range profiles {
			if profiles[i].ID == group {
				index = i
				break
			}
		}
		if index < 0 {
			name := actor.Name
			for _, order := range state.Orders {
				if order.CustomerID == actor.ID && order.CompanyID == actor.CompanyID && order.Customer != "" {
					name = order.Customer
					break
				}
			}
			profiles = append(profiles, CustomerProfile{ID: group, Name: name, AccountIDs: []string{}, Companies: []CustomerCompany{{ID: actor.CompanyID, Name: actor.CompanyID}}})
			index = len(profiles) - 1
		}
		profiles[index].AccountIDs = append(profiles[index].AccountIDs, actor.ID)
		known[actor.ID] = true
	}
	return profiles
}

func customerDirectoryView(state *State, actor Actor) map[string]any {
	customers := []map[string]any{}
	manage := actor.Role == "admin" || actor.Role == "dispatcher"
	for _, profile := range directoryProfiles(state) {
		accounts := []Actor{}
		companies := []CustomerCompany{}
		for _, id := range profile.AccountIDs {
			for _, account := range state.Accounts {
				if account.Actor.ID == id && account.Actor.Role == "customer" && activeActor(account.Actor) && (manage || account.Actor.ID == actor.ID && account.Actor.CompanyID == actor.CompanyID) {
					accounts = append(accounts, account.Actor)
				}
			}
		}
		if !manage && len(accounts) == 0 {
			continue
		}
		for _, company := range profile.Companies {
			if manage || company.ID == actor.CompanyID {
				companies = append(companies, company)
			}
		}
		customers = append(customers, map[string]any{"id": profile.ID, "name": profile.Name, "accounts": accounts, "companies": companies})
	}
	return map[string]any{"customers": customers, "canManage": manage}
}

func (s *Service) registerCustomerDirectoryRoutes(protected func(string, func(http.ResponseWriter, *http.Request, Actor))) {
	protected("GET /api/v38/customer-directory", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err == nil {
			err = roles(actor, "admin", "dispatcher", "customer")
		}
		if err != nil {
			writeFailure(w, err)
			return
		}
		if err = s.auditLocked(actor, "customer_directory_read", "customer_directory", "success"); err != nil {
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, customerDirectoryView(&s.state, actor))
	})
	protected("POST /api/v38/customer-directory", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 201, func(state *State, raw []byte) (any, error) {
			var input customerDirectoryInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.mutateCustomerDirectory(state, actor, input)
		})
	})
}

func (s *Service) mutateCustomerDirectory(state *State, actor Actor, input customerDirectoryInput) (any, error) {
	if err := roles(actor, "admin", "dispatcher"); err != nil {
		return nil, err
	}
	state.Customers = directoryProfiles(state)
	var profile *CustomerProfile
	if input.Operation == "customer" {
		if !textValid(input.Name, 1, 200) {
			return nil, fail(422, "invalid_customer", "客户名称必填，最多200字符")
		}
		state.Customers = append(state.Customers, CustomerProfile{ID: randomID("cust_"), Name: strings.TrimSpace(input.Name), AccountIDs: []string{}, Companies: []CustomerCompany{}})
		profile = &state.Customers[len(state.Customers)-1]
	} else {
		for i := range state.Customers {
			if state.Customers[i].ID == input.CustomerID {
				profile = &state.Customers[i]
				break
			}
		}
		if profile == nil {
			return nil, fail(422, "invalid_customer", "请选择有效客户档案")
		}
	}
	companyID, accountID := "", ""
	if input.Operation == "company" || input.Operation == "customer" && input.CompanyName != "" {
		name := input.CompanyName
		if input.Operation == "company" {
			name = input.Name
		}
		if !textValid(name, 1, 200) {
			return nil, fail(422, "invalid_company", "企业名称必填，最多200字符")
		}
		companyID = randomID("company_")
		profile.Companies = append(profile.Companies, CustomerCompany{ID: companyID, Name: strings.TrimSpace(name)})
	}
	if input.Operation == "account" || input.Operation == "customer" && input.Username != "" {
		if err := validatePasswordEmoji(input.Password, input.ConfirmPassword); err != nil {
			return nil, err
		}
		if companyID == "" {
			companyID = input.CompanyID
		}
		allowedCompany := false
		for _, company := range profile.Companies {
			allowedCompany = allowedCompany || company.ID == companyID
		}
		username := strings.ToLower(strings.TrimSpace(input.Username))
		if !allowedCompany || !validAuthUsername(username) || input.Password != input.ConfirmPassword || utf8.RuneCountInString(input.Password) < 8 || len(input.Password) > 256 || !textValid(input.AccountName, 0, 80) {
			return nil, fail(422, "invalid_customer_account", "请选本客户企业，填写有效用户名和至少8字符的一致密码")
		}
		for _, account := range state.Accounts {
			if strings.EqualFold(account.Actor.Username, username) {
				return nil, fail(409, "account_exists", "该用户名已被使用")
			}
		}
		name := strings.TrimSpace(input.AccountName)
		if name == "" {
			name = profile.Name
		}
		salt := randomID("")
		hash, err := passwordHash(input.Password, salt)
		if err != nil {
			return nil, err
		}
		accountID = randomID("customer_")
		created := Actor{ID: accountID, Username: username, Name: name, Role: "customer", CompanyID: companyID, Status: "active", AuthVersion: 1}
		state.Accounts = append(state.Accounts, Account{Actor: created, Salt: salt, Hash: hash})
		profile.AccountIDs = append(profile.AccountIDs, accountID)
	}
	if input.Operation != "customer" && input.Operation != "company" && input.Operation != "account" {
		return nil, fail(422, "invalid_directory_operation", "请选择新建客户、企业或客户账户")
	}
	s.appendAudit(state, actor, "customer_directory_"+input.Operation, profile.ID, "success")
	out := customerDirectoryView(state, actor)
	out["id"], out["customerId"], out["accountId"], out["companyId"] = profile.ID, profile.ID, accountID, companyID
	return out, nil
}

func validateCustomerDirectory(state State) error {
	profileIDs, assignedAccounts := map[string]bool{}, map[string]bool{}
	for _, profile := range state.Customers {
		if profile.ID == "" || profileIDs[profile.ID] || !textValid(profile.Name, 1, 200) {
			return fmt.Errorf("invalid customer directory profile")
		}
		profileIDs[profile.ID] = true
		companies := map[string]bool{}
		for _, company := range profile.Companies {
			if company.ID == "" || companies[company.ID] || !textValid(company.Name, 1, 200) {
				return fmt.Errorf("invalid customer company")
			}
			companies[company.ID] = true
		}
		for _, id := range profile.AccountIDs {
			matched := false
			for _, account := range state.Accounts {
				matched = matched || account.Actor.ID == id && account.Actor.Role == "customer" && companies[account.Actor.CompanyID]
			}
			if !matched || assignedAccounts[id] {
				return fmt.Errorf("invalid customer account association")
			}
			assignedAccounts[id] = true
		}
	}
	return nil
}

func (s *Service) replayCustomerDirectory(actor Actor, request CachedRequest) (json.RawMessage, int, error) {
	if err := roles(actor, "admin", "dispatcher"); err != nil {
		return nil, 0, err
	}
	var selected struct {
		ID         string `json:"id"`
		CustomerID string `json:"customerId"`
		AccountID  string `json:"accountId"`
		CompanyID  string `json:"companyId"`
	}
	if json.Unmarshal(request.Body, &selected) != nil {
		return nil, 0, fail(409, "retry_result_unavailable", "客户档案原请求结果无法核对")
	}
	out := customerDirectoryView(&s.state, actor)
	out["id"], out["customerId"], out["accountId"], out["companyId"] = selected.ID, selected.CustomerID, selected.AccountID, selected.CompanyID
	body, err := json.Marshal(out)
	return body, request.Status, err
}
