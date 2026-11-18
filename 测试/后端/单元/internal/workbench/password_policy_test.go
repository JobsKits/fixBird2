package workbench

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestPasswordEmojiPolicyPreservesTextAndRejectsSequences(t *testing.T) {
	for _, value := range []string{
		"Password0123456789#*!@_$%^&()-=+[]{};:'\",.<>/?\\|`~",
		"简繁藏བོད་ཡིགEnglish日本語FrançaisEspañolDeutschРусский한국어",
		"©®™e\u0301𠮷𝄞𝑥", "क्\u200Dष", "text\uFE0E", "123#*क्\u200Dष",
		"©123क्\u200Dष", "®123क्\u200Dष", "™123क्\u200Dष", "©text\U000E0067\U000E007F",
	} {
		if err := validatePasswordEmoji(value); err != nil {
			t.Errorf("ordinary password text rejected: %q: %v", value, err)
		}
	}
	for _, value := range []string{
		"😀", "❤", "❤️", "♥", "☹", "☀", "🇨🇳", "🇨", "🏽", "👍🏽", "👩‍💻",
		"👨‍👩‍👧‍👦", "1️⃣", "1\u20E3", "#️⃣", "*️⃣", "©️", "®\u200D文字", "™\U000E0067\U000E007F",
		"🏴\U000E0067\U000E0062\U000E007F", "plain\uFE0F", "\u20E3",
		"©\u200D", "©\uFE0E\u200D", "©\u0301\u200D", "©\u200C\u200D", "®\u0301\U000E0067\U000E007F",
	} {
		t.Run(fmt.Sprintf("U+%X", []rune(value)), func(t *testing.T) {
			err := validatePasswordEmoji("Password8" + value)
			expectCode(t, err, "invalid_password")
			if err.Error() != "密码不能包含表情符号" {
				t.Fatal("inconsistent password feedback", err)
			}
		})
	}
}

func TestPasswordEmojiDataMatchesSharedContract(t *testing.T) {
	path := filepath.Join("..", "..", "..", "..", "前端", "PC端", "原生共享契约", "password-emoji-ranges.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var contract struct {
		UnicodeVersion string               `json:"unicodeVersion"`
		Properties     map[string][][2]rune `json:"properties"`
	}
	if err := json.Unmarshal(raw, &contract); err != nil {
		t.Fatal(err)
	}
	if contract.UnicodeVersion != "18.0.0" || !reflect.DeepEqual(contract.Properties["Emoji"], passwordEmojiRanges) || !reflect.DeepEqual(contract.Properties["Emoji_Presentation"], passwordEmojiPresentationRanges) {
		t.Fatal("backend emoji data diverged from the native desktop contract")
	}
	for _, interval := range contract.Properties["Emoji"] {
		for scalar := interval[0]; scalar <= interval[1]; scalar++ {
			want := scalar > 0x7F && scalar != 0x00A9 && scalar != 0x00AE && scalar != 0x2122
			if got := passwordContainsEmoji(string(scalar)); got != want {
				t.Errorf("emoji policy mismatch for U+%X: got %v want %v", scalar, got, want)
			}
		}
	}
}

func TestPublicPasswordEmojiRejectionKeepsCodeCredentialsAndSessions(t *testing.T) {
	t.Setenv("WB_SMTP_HOST", "")
	s, persistence := testService(t)
	email := "emoji-policy@example.test"
	code := authFixtureCode(t, s, email, "register")
	before := len(s.state.Accounts)
	for _, tail := range []string{"😀", "❤", "🇨🇳", "👍🏽", "👩‍💻", "1️⃣"} {
		body := authFixtureBody(email, "emoji-policy", code, "Password8"+tail)
		status, out := publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010")
		if status != 422 || out["error"] != "invalid_password" || out["message"] != "密码不能包含表情符号" || len(s.state.Accounts) != before {
			t.Fatalf("API accepted emoji registration or changed state: %d %v", status, out)
		}
	}
	const password = "合法Password9#*©®™123क्\u200Dष"
	body := authFixtureBody(email, "emoji-policy", code, password)
	if status, out := publicAuthRequest(t, s, "register", body, "localhost", "127.0.0.1:3010"); status != 201 {
		t.Fatalf("valid retry could not use the unconsumed code: %d %v", status, out)
	}
	token, actor, err := s.login(email, password, "emoji-policy")
	if err != nil {
		t.Fatal(err)
	}
	resetCode := authFixtureCode(t, s, email, "reset_password")
	stateBefore, _ := json.Marshal(s.state)
	savesBefore := persistence.saves
	for _, field := range []string{"password", "confirmPassword"} {
		reset := authFixtureBody(email, "", resetCode, "Changed-Password9")
		reset[field] += "😀"
		if status, out := publicAuthRequest(t, s, "reset-password", reset, "localhost", "127.0.0.1:3010"); status != 422 || out["message"] != "密码不能包含表情符号" {
			t.Fatalf("emoji reset accepted: %d %v", status, out)
		}
		stateAfter, _ := json.Marshal(s.state)
		if string(stateBefore) != string(stateAfter) || persistence.saves != savesBefore {
			t.Fatal("rejected reset changed credentials, authVersion or persisted state")
		}
		if current, err := s.authenticate(token); err != nil || current.AuthVersion != actor.AuthVersion {
			t.Fatal("rejected reset revoked the existing session", err)
		}
	}
	reset := authFixtureBody(email, "", resetCode, "新密码Password9#*")
	if status, out := publicAuthRequest(t, s, "reset-password", reset, "localhost", "127.0.0.1:3010"); status != 200 {
		t.Fatalf("valid reset retry failed: %d %v", status, out)
	}
	if _, err := s.authenticate(token); err == nil {
		t.Fatal("successful reset retained the old session")
	}
	restarted, err := New(persistence)
	if err != nil {
		t.Fatal(err)
	}
	if _, current, err := restarted.login(email, reset["password"], "emoji-policy-restart"); err != nil || current.AuthVersion != actor.AuthVersion+1 {
		t.Fatal("valid reset password did not survive restart", err)
	}
}

func TestCustomerDirectoryPasswordEmojiRejectedAtomically(t *testing.T) {
	s, persistence := testService(t)
	before, _ := json.Marshal(s.state)
	profile := directoryProfiles(&s.state)[0]
	for _, operation := range []string{"customer", "account"} {
		for _, field := range []string{"password", "confirmPassword"} {
			input := map[string]string{"operation": operation, "name": "密码策略测试", "companyName": "合成企业", "customerId": profile.ID, "companyId": profile.Companies[0].ID, "username": "emoji-directory", "password": "Password9#*", "confirmPassword": "Password9#*"}
			input[field] += "❤"
			response := loanHTTPFixture(t, s, "POST", "/customer-directory", "admin", operation+field, input)
			var out map[string]any
			if err := json.Unmarshal(response.Body.Bytes(), &out); err != nil {
				t.Fatal(err)
			}
			if response.Code != 422 || out["message"] != "密码不能包含表情符号" {
				t.Fatalf("directory API bypassed password validation: %d %v", response.Code, out)
			}
		}
	}
	// HTTP denial audit may persist; business relations and credentials must remain identical.
	after := s.state
	after.Audit = nil
	var original State
	if err := json.Unmarshal(before, &original); err != nil {
		t.Fatal(err)
	}
	original.Audit = nil
	originalJSON, _ := json.Marshal(original)
	afterJSON, _ := json.Marshal(after)
	if string(originalJSON) != string(afterJSON) {
		t.Fatal("rejected account creation changed customer/company/account state")
	}
	restarted, err := New(persistence)
	if err != nil || len(restarted.state.Accounts) != len(original.Accounts) {
		t.Fatal("rejected credentials survived in persistent state", err)
	}
}

func TestLoginPasswordEmojiRejectsLegacyHashWithoutChangingCredentials(t *testing.T) {
	s, _ := testService(t)
	for i := range s.state.Accounts {
		if s.state.Accounts[i].Actor.Username == "customer" {
			account := &s.state.Accounts[i]
			hash, err := passwordHash("Legacy-Password😀", account.Salt)
			if err != nil {
				t.Fatal(err)
			}
			account.Hash = hash
		}
	}
	before := append([]Account(nil), s.state.Accounts...)
	status, out := publicAuthRequest(t, s, "login", map[string]string{"username": "customer", "password": "Legacy-Password😀"}, "localhost", "127.0.0.1:3010")
	if status != 422 || out["message"] != "密码不能包含表情符号" || len(s.sessions) != 0 || !reflect.DeepEqual(before, s.state.Accounts) {
		t.Fatalf("legacy emoji hash bypassed login policy: %d %v", status, out)
	}
	if _, _, err := s.login("engineer", "Demo-Repair-2026!", "emoji-policy-ordinary"); err != nil {
		t.Fatal("existing ordinary password no longer works", err)
	}
	if _, _, err := s.login("admin", "1234", "emoji-policy-demo"); err != nil {
		t.Fatal("demo administrator password no longer works", err)
	}
}
