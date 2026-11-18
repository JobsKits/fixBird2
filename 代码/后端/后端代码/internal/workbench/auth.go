// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"math/big"
	"net"
	"net/http"
	"net/mail"
	"os"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

type authChallenge struct {
	Digest   [32]byte
	Sent     time.Time
	Expires  time.Time
	Attempts int
	Ready    bool
}

type publicAuthInput struct {
	Username        string `json:"username"`
	Name            string `json:"name"`
	Email           string `json:"email"`
	Code            string `json:"code"`
	Password        string `json:"password"`
	ConfirmPassword string `json:"confirmPassword"`
}

func normalizedAuthEmail(value string) (string, error) {
	value = strings.ToLower(strings.TrimSpace(value))
	parsed, err := mail.ParseAddress(value)
	if err != nil || parsed.Address != value || len(value) > 254 || !strings.Contains(value, "@") || strings.ContainsAny(value, "\r\n") {
		return "", fail(422, "invalid_email", "请输入有效邮箱地址")
	}
	return value, nil
}

func validAuthUsername(value string) bool {
	if n := utf8.RuneCountInString(value); n < 3 || n > 32 {
		return false
	}
	for _, r := range value {
		if !unicode.IsLetter(r) && !unicode.IsDigit(r) && r != '_' && r != '-' {
			return false
		}
	}
	return true
}

func authCodeDigest(email, purpose, code string) [32]byte {
	return sha256.Sum256([]byte(email + "\x00" + purpose + "\x00" + code))
}

func authLoopbackHost(host string) bool {
	if hostname, _, err := net.SplitHostPort(host); err == nil {
		host = hostname
	}
	host = strings.Trim(host, "[]")
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func localAuthRequest(r *http.Request) bool {
	remote, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil || !authLoopbackHost(remote) || !authLoopbackHost(r.Host) {
		return false
	}
	// A local reverse proxy must not turn a remote request into a local code disclosure.
	return r.Header.Get("Forwarded") == "" && r.Header.Get("X-Forwarded-For") == "" && r.Header.Get("X-Forwarded-Host") == ""
}

func (s *Service) registerPublicAuth(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v38/auth/email-code", s.requestAuthCode)
	mux.HandleFunc("POST /api/v38/register", func(w http.ResponseWriter, r *http.Request) {
		s.completePublicAuth(w, r, false)
	})
	mux.HandleFunc("POST /api/v38/reset-password", func(w http.ResponseWriter, r *http.Request) {
		s.completePublicAuth(w, r, true)
	})
}

func (s *Service) requestAuthCode(w http.ResponseWriter, r *http.Request) {
	raw, err := readBody(w, r)
	if err != nil {
		writeFailure(w, err)
		return
	}
	var input struct {
		Email   string `json:"email"`
		Purpose string `json:"purpose"`
	}
	if err = decodeStrict(raw, &input); err != nil {
		writeFailure(w, err)
		return
	}
	email, err := normalizedAuthEmail(input.Email)
	if err != nil {
		writeFailure(w, err)
		return
	}
	if input.Purpose != "register" && input.Purpose != "reset_password" {
		writeFailure(w, fail(422, "invalid_purpose", "验证码用途无效"))
		return
	}
	remote, _, _ := net.SplitHostPort(r.RemoteAddr)
	key := email + ":" + input.Purpose
	s.mu.Lock()
	now := s.now()
	for k, challenge := range s.authCodes {
		if !challenge.Expires.After(now) {
			delete(s.authCodes, k)
		}
	}
	for k, rate := range s.authRates {
		if !rate.Until.After(now) {
			delete(s.authRates, k)
		}
	}
	rate := s.authRates[remote]
	if !rate.Until.After(now) {
		rate = loginAttempt{Until: now.Add(10 * time.Minute)}
	}
	rate.Count++
	if len(s.authRates) >= 4096 && s.authRates[remote].Until.IsZero() || rate.Count > 20 || len(s.authCodes) >= 1000 || now.Sub(s.authCodes[key].Sent) < time.Minute {
		s.mu.Unlock()
		writeFailure(w, fail(429, "auth_rate_limited", "验证码发送过于频繁，请稍后再试"))
		return
	}
	s.authRates[remote] = rate
	number, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		s.mu.Unlock()
		writeFailure(w, err)
		return
	}
	code := fmt.Sprintf("%06d", number.Int64())
	challenge := authChallenge{Digest: authCodeDigest(email, input.Purpose, code), Sent: now, Expires: now.Add(10 * time.Minute)}
	s.authCodes[key] = challenge
	demo := s.state.Settings.Demo && localAuthRequest(r) && os.Getenv("WB_SMTP_HOST") == ""
	s.mu.Unlock()
	if !demo {
		err = deliverAuthEmail(r.Context(), email, input.Purpose, code)
	}
	s.mu.Lock()
	if current, found := s.authCodes[key]; found && current.Digest == challenge.Digest {
		if err != nil {
			delete(s.authCodes, key)
		} else {
			current.Ready = true
			s.authCodes[key] = current
		}
	}
	s.mu.Unlock()
	if err != nil {
		// Do not expose recipient, challenge or SMTP diagnostic text in logs or responses.
		writeFailure(w, fail(503, "email_unavailable", "邮件服务未配置或暂不可用，请联系管理员"))
		return
	}
	out := map[string]any{"ok": true, "message": "验证码已发送", "expiresIn": 600, "retryAfter": 60, "delivery": "email"}
	if demo {
		out["delivery"], out["demoCode"] = "demo", code
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Service) completePublicAuth(w http.ResponseWriter, r *http.Request, reset bool) {
	raw, err := readBody(w, r)
	if err != nil {
		writeFailure(w, err)
		return
	}
	var input publicAuthInput
	if err = decodeStrict(raw, &input); err != nil {
		writeFailure(w, err)
		return
	}
	actor, err := s.applyPublicAuth(input, reset)
	if err != nil {
		writeFailure(w, err)
		return
	}
	if reset {
		writeJSON(w, 200, map[string]any{"ok": true, "message": "密码已重置，请重新登录"})
	} else {
		writeJSON(w, 201, map[string]any{"ok": true, "message": "注册成功，请登录", "actor": actor})
	}
}

func (s *Service) applyPublicAuth(input publicAuthInput, reset bool) (Actor, error) {
	email, err := normalizedAuthEmail(input.Email)
	if err != nil {
		return Actor{}, err
	}
	input.Username = strings.ToLower(strings.TrimSpace(input.Username))
	input.Name = strings.TrimSpace(input.Name)
	if !reset && (!validAuthUsername(input.Username) || utf8.RuneCountInString(input.Name) > 80) {
		return Actor{}, fail(422, "invalid_username", "用户名须为3至32个字母、汉字、数字、下划线或短横线，姓名最多80个字符")
	}
	if err := validatePasswordEmoji(input.Password, input.ConfirmPassword); err != nil {
		return Actor{}, err
	}
	if input.Password != input.ConfirmPassword || utf8.RuneCountInString(input.Password) < 8 || len(input.Password) > 256 {
		return Actor{}, fail(422, "invalid_password", "密码须至少8个字符、最多256字节，两次输入须一致")
	}
	purpose := "register"
	if reset {
		purpose = "reset_password"
	}
	key := email + ":" + purpose
	s.mu.Lock()
	defer s.mu.Unlock()
	challenge, exists := s.authCodes[key]
	digest := authCodeDigest(email, purpose, input.Code)
	if !exists || !challenge.Ready || !challenge.Expires.After(s.now()) || challenge.Attempts >= 5 || len(input.Code) != 6 || subtle.ConstantTimeCompare(digest[:], challenge.Digest[:]) != 1 {
		if exists {
			challenge.Attempts++
			s.authCodes[key] = challenge
		}
		return Actor{}, fail(422, "invalid_code", "邮箱验证码无效或已过期")
	}
	data, err := json.Marshal(s.state)
	if err != nil {
		return Actor{}, err
	}
	var next State
	if err = json.Unmarshal(data, &next); err != nil {
		return Actor{}, err
	}
	index := -1
	for i, account := range next.Accounts {
		if account.Email == email {
			index = i
		}
		if !reset && (account.Email == email || strings.EqualFold(account.Actor.Username, input.Username)) {
			return Actor{}, fail(409, "account_exists", "该用户名或邮箱已被使用")
		}
	}
	if reset && (index < 0 || !activeActor(next.Accounts[index].Actor)) {
		return Actor{}, fail(422, "invalid_recovery", "无法重置此邮箱对应的账号，请联系管理员")
	}
	salt := randomID("")
	hash, err := passwordHash(input.Password, salt)
	if err != nil {
		return Actor{}, err
	}
	var actor Actor
	kind := "register"
	if reset {
		account := &next.Accounts[index]
		account.Salt, account.Hash = salt, hash
		account.Actor.AuthVersion++
		actor = account.Actor
		kind = "reset_password"
	} else {
		if input.Name == "" {
			input.Name = input.Username
		}
		actor = Actor{ID: randomID("customer_"), Username: input.Username, Name: input.Name, Role: "customer", CompanyID: randomID("company_"), Status: "active", AuthVersion: 1}
		next.Accounts = append(next.Accounts, Account{Actor: actor, Salt: salt, Hash: hash, Email: email})
	}
	s.appendAudit(&next, actor, kind, "account", "success")
	if err = validateState(next); err != nil {
		return Actor{}, err
	}
	data, err = json.Marshal(next)
	if err != nil {
		return Actor{}, err
	}
	if err = s.persistence.Save(data); err != nil {
		return Actor{}, err
	}
	s.state = next
	delete(s.authCodes, key)
	if reset {
		for token, current := range s.sessions {
			if current.Actor.ID == actor.ID {
				delete(s.sessions, token)
			}
		}
	}
	return actor, nil
}
