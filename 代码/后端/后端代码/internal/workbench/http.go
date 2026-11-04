package workbench

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"path/filepath"
	"strings"
)

func decodeStrict(raw []byte, value any) error {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(value); err != nil {
		return fail(422, "invalid_json", "请求 JSON 无效或包含未知字段")
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return fail(422, "invalid_json", "请求须只包含一个 JSON 对象")
	}
	return nil
}
func readBody(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	r.Body = http.MaxBytesReader(w, r.Body, 12*1024*1024)
	value, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, fail(413, "body_too_large", "请求体超过允许大小")
	}
	return value, nil
}
func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func writeFailure(w http.ResponseWriter, err error) {
	var business *businessError
	if errors.As(err, &business) {
		writeJSON(w, business.Status, map[string]string{"error": business.Code, "message": business.Message})
		return
	}
	log.Printf("workbench operation failed (%T)", err)
	writeJSON(w, 500, map[string]string{"error": "internal_error", "message": "保存未完成，请核对请求结果后重试；未提交半套记录"})
}
func bearer(r *http.Request) string {
	parts := strings.Fields(r.Header.Get("Authorization"))
	if len(parts) == 2 && parts[0] == "Bearer" {
		return parts[1]
	}
	return ""
}

func (s *Service) Handler(webDir string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v38/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"status": "ok", "version": "3.8", "mode": "synthetic_demo"})
	})
	mux.HandleFunc("POST /api/v38/login", func(w http.ResponseWriter, r *http.Request) {
		raw, err := readBody(w, r)
		if err != nil {
			writeFailure(w, err)
			return
		}
		var input struct {
			Username string `json:"username"`
			Password string `json:"password"`
		}
		if err = decodeStrict(raw, &input); err != nil {
			writeFailure(w, err)
			return
		}
		remote, _, _ := net.SplitHostPort(r.RemoteAddr)
		token, actor, err := s.login(input.Username, input.Password, remote)
		if err != nil {
			if auditErr := s.audit(Actor{}, "login", "session", "denied"); auditErr != nil {
				writeFailure(w, auditErr)
				return
			}
			writeFailure(w, err)
			return
		}
		if err = s.audit(actor, "login", "session", "success"); err != nil {
			s.mu.Lock()
			delete(s.sessions, token)
			s.mu.Unlock()
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, map[string]any{"token": token, "actor": actor})
	})
	protected := func(pattern string, fn func(http.ResponseWriter, *http.Request, Actor)) {
		mux.HandleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			actor, err := s.authenticate(bearer(r))
			if err != nil {
				if auditErr := s.audit(Actor{}, "authentication", pattern, "denied"); auditErr != nil {
					writeFailure(w, auditErr)
					return
				}
				writeFailure(w, err)
				return
			}
			fn(w, r, actor)
		})
	}
	protected("GET /api/v38/session", func(w http.ResponseWriter, r *http.Request, actor Actor) { writeJSON(w, 200, actor) })
	protected("POST /api/v38/logout", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		delete(s.sessions, bearer(r))
		err := s.auditLocked(actor, "logout", "session", "success")
		s.mu.Unlock()
		if err != nil {
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, map[string]bool{"ok": true})
	})
	protected("GET /api/v38/bootstrap", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, s.dashboard(actor))
	})
	protected("GET /api/v38/orders", s.listOrders)
	protected("GET /api/v38/orders/{id}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		order, err := findOrder(&s.state, r.PathValue("id"), actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		if err = s.auditLocked(actor, "order_read", order.ID, "success"); err != nil {
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, s.view(*order, &s.state, actor))
	})
	protected("POST /api/v38/orders", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 201, func(state *State, raw []byte) (any, error) {
			var input CreateOrderInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.createOrder(state, actor, input)
		})
	})
	protected("POST /api/v38/orders/{id}/actions", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var action Action
			if err := decodeStrict(raw, &action); err != nil {
				return nil, err
			}
			return s.act(state, actor, r.PathValue("id"), action)
		})
	})
	protected("GET /api/v38/orders/{id}/evidence/{evidenceId}", s.downloadEvidence)
	protected("POST /api/v38/loans", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 201, func(state *State, raw []byte) (any, error) {
			var input LoanInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.createLoan(state, actor, input)
		})
	})
	protected("POST /api/v38/loans/{id}/actions", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input Action
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.loanAction(state, actor, r.PathValue("id"), input)
		})
	})
	protected("POST /api/v38/purchases", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 201, func(state *State, raw []byte) (any, error) {
			var input PurchaseInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.createPurchase(state, actor, input)
		})
	})
	protected("POST /api/v38/purchases/{id}/receive", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input PurchaseReceive
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.receivePurchase(state, actor, r.PathValue("id"), input)
		})
	})
	protected("POST /api/v38/auto-accept", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input struct{}
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.autoAccept(state, actor)
		})
	})
	protected("POST /api/v38/settings", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			if err := roles(actor, "admin"); err != nil {
				return nil, err
			}
			var input struct {
				CompanyAddress  string `json:"companyAddress"`
				CompanyReceiver string `json:"companyReceiver"`
				CompanyPhone    string `json:"companyPhone"`
				ReminderHours   int    `json:"reminderHours"`
				RemarkLimit     int    `json:"remarkLimit"`
			}
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			if !textValid(input.CompanyAddress, 1, 500) || !textValid(input.CompanyReceiver, 1, 100) || !textValid(input.CompanyPhone, 1, 100) || input.ReminderHours < 1 || input.ReminderHours > 168 {
				return nil, fail(422, "invalid_settings", "公司寄送信息必填，提醒时间须1—168小时")
			}
			if input.RemarkLimit == 0 {
				input.RemarkLimit = 2000
			}
			if input.RemarkLimit < 100 || input.RemarkLimit > 10000 {
				return nil, fail(422, "invalid_settings", "备注长度须100—10000字")
			}
			state.Settings = Settings{CompanyAddress: input.CompanyAddress, CompanyReceiver: input.CompanyReceiver, CompanyPhone: input.CompanyPhone, ReminderHours: input.ReminderHours, RemarkLimit: input.RemarkLimit, Demo: true}
			return state.Settings, nil
		})
	})
	protected("GET /api/v38/export", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		if err = roles(actor, "admin", "dispatcher", "finance", "customer"); err != nil {
			if auditErr := s.auditLocked(actor, "export", "authorized_workbench", "denied"); auditErr != nil {
				writeFailure(w, auditErr)
				return
			}
			writeFailure(w, err)
			return
		}
		resources := []string{}
		for _, order := range s.state.Orders {
			if visible(order, actor) {
				resources = append(resources, order.ID)
			}
		}
		if err = s.auditLocked(actor, "export", "authorized_workbench", "success", resources...); err != nil {
			writeFailure(w, err)
			return
		}
		w.Header().Set("Content-Disposition", "attachment; filename=workbench-v38-demo.json")
		writeJSON(w, 200, s.bootstrap(actor))
	})
	protected("GET /api/v38/audit", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		if err = roles(actor, "admin"); err != nil {
			writeFailure(w, err)
			return
		}
		query, err := parseOrderQuery(r.URL.Query())
		if err != nil {
			writeFailure(w, err)
			return
		}
		items := []AuditEvent{}
		total := len(s.state.Audit)
		start := (query.Page - 1) * query.PageSize
		for i := start; i < min(start+query.PageSize, total); i++ {
			items = append(items, s.state.Audit[total-1-i])
		}
		writeJSON(w, 200, map[string]any{"items": items, "total": total, "page": query.Page, "pageSize": query.PageSize})
	})
	protected("GET /api/v38/accounts", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if err := roles(actor, "admin"); err != nil {
			writeFailure(w, err)
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		accounts := []Actor{}
		for _, a := range s.state.Accounts {
			accounts = append(accounts, a.Actor)
		}
		writeJSON(w, 200, accounts)
	})
	protected("POST /api/v38/accounts/{id}/status", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			if err := roles(actor, "admin"); err != nil {
				return nil, err
			}
			var input struct {
				Status string `json:"status"`
				Reason string `json:"reason"`
			}
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			if input.Status != "active" && input.Status != "disabled" || !textValid(input.Reason, 1, 2000) || r.PathValue("id") == actor.ID {
				return nil, fail(422, "invalid_account_status", "请选择状态及原因，不允许停用自己")
			}
			for i := range state.Accounts {
				if state.Accounts[i].Actor.ID == r.PathValue("id") {
					before := state.Accounts[i].Actor
					state.Accounts[i].Actor.Status = input.Status
					state.Accounts[i].Actor.AuthVersion++
					index := s.appendAudit(state, actor, "account_status", before.ID, "success")
					state.Audit[index].Reason = input.Reason
					state.Audit[index].Before, state.Audit[index].After = before.Status, input.Status
					state.Audit[index].AuthBefore, state.Audit[index].AuthAfter = before.AuthVersion, before.AuthVersion+1
					return state.Accounts[i].Actor, nil
				}
			}
			return nil, fail(404, "not_found", "账号不存在")
		})
	})
	if webDir != "" {
		mux.Handle("GET /", http.FileServer(http.Dir(webDir)))
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'")
		if strings.HasPrefix(r.URL.Path, "/api/") {
			w.Header().Set("Cache-Control", "no-store")
		}
		mux.ServeHTTP(w, r)
	})
}

func (s *Service) write(w http.ResponseWriter, r *http.Request, actor Actor, status int, fn func(*State, []byte) (any, error)) {
	raw, err := readBody(w, r)
	if err != nil {
		writeFailure(w, err)
		return
	}
	response, resultStatus, err := s.transact(actor, r.Method+" "+r.URL.Path, r.Header.Get("Idempotency-Key"), raw, status, func(state *State) (any, error) { return fn(state, raw) })
	if err != nil {
		writeFailure(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(resultStatus)
	_, _ = w.Write(response)
}
func (s *Service) bootstrap(actor Actor) map[string]any {
	result := s.bootstrapMetadata(actor)
	orders := []Order{}
	for _, order := range s.state.Orders {
		if visible(order, actor) {
			orders = append(orders, s.view(order, &s.state, actor))
		}
	}
	result["orders"] = orders
	return result
}
func (s *Service) bootstrapMetadata(actor Actor) map[string]any {
	parts := []Part{}
	loans := []Loan{}
	purchases := []Purchase{}
	if internal(actor) {
		parts = append(parts, s.state.Parts...)
	}
	for _, l := range s.state.Loans {
		if actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "dispatcher" || actor.Role == "engineer" && l.BorrowerID == actor.ID {
			loans = append(loans, l)
		}
	}
	for _, p := range s.state.Purchases {
		if actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "finance" || actor.Role == "dispatcher" || actor.Role == "supplier" && (p.Supplier == actor.ID || p.Supplier == actor.Name) {
			purchases = append(purchases, p)
		}
	}
	return map[string]any{"actor": actor, "states": States, "parts": parts, "loans": loans, "purchases": purchases, "settings": s.state.Settings}
}
func (s *Service) listOrders(w http.ResponseWriter, r *http.Request, actor Actor) {
	query, err := parseOrderQuery(r.URL.Query())
	if err != nil {
		writeFailure(w, err)
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err = s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	writeJSON(w, 200, s.queryOrders(actor, query))
}
func matchesFilter(o Order, a Actor, filter string) bool {
	switch filter {
	case "", "all":
		return true
	case "mine":
		return o.OwnerID == a.ID || o.AssigneeID == a.ID || a.Role == "customer"
	case "accepted_uncompleted":
		return o.Outcome == "accepted" && o.Status != "completed"
	case "documents_pending":
		return o.Documents.Requirement == "required" && !o.Documents.Prepared
	case "documents_unsent":
		return o.Documents.Prepared && !o.Documents.Sent
	case "invoice_pending":
		return o.InvoiceRequirement == "required" && o.Summary.InvoiceStatus != "已满足"
	case "cash_pending":
		return o.Summary.PendingCashCents > 0
	case "receivable":
		return o.Summary.RemainingCents > 0
	case "overpaid":
		return o.Summary.OverpaidCents > 0
	case "failed":
		return o.Outcome == "failed"
	case "blocked":
		for _, issue := range o.Issues {
			if !issue.Resolved {
				return true
			}
		}
		return false
	case "settling":
		return o.Status == "settling"
	case "pending_completion":
		return o.Status == "pending_completion"
	case "completed":
		return o.Status == "completed"
	default:
		return false
	}
}
func (s *Service) downloadEvidence(w http.ResponseWriter, r *http.Request, actor Actor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	order, err := findOrder(&s.state, r.PathValue("id"), actor)
	if err != nil {
		if auditErr := s.auditLocked(actor, "download", "unavailable_evidence", "denied"); auditErr != nil {
			writeFailure(w, auditErr)
			return
		}
		writeFailure(w, err)
		return
	}
	for _, e := range order.Evidence {
		if e.ID != r.PathValue("evidenceId") || e.Deleted || !canReadEvidence(*order, e, actor) {
			continue
		}
		if err = s.auditLocked(actor, "download", order.ID+"/"+e.ID, "success"); err != nil {
			writeFailure(w, err)
			return
		}
		data := []byte(e.Text)
		if e.Data != "" {
			data, err = decodeBase64(e.Data)
			if err != nil {
				writeFailure(w, err)
				return
			}
		}
		mime := e.MIME
		if e.Kind == "text" {
			mime = "text/plain; charset=utf-8"
		}
		if mime == "" {
			mime = "application/octet-stream"
		}
		w.Header().Set("Content-Type", mime)
		w.Header().Set("Cache-Control", "no-store")
		name := filepath.Base(e.Name)
		name = strings.ReplaceAll(strings.ReplaceAll(name, "\"", ""), "\r", "")
		name = strings.ReplaceAll(name, "\n", "")
		w.Header().Set("Content-Disposition", "attachment; filename*=UTF-8''"+urlPathEscape(name))
		w.WriteHeader(200)
		_, _ = w.Write(data)
		return
	}
	if err = s.auditLocked(actor, "download", order.ID, "denied"); err != nil {
		writeFailure(w, err)
		return
	}
	writeFailure(w, fail(404, "not_found", "文件不存在、已删除或无访问权限"))
}
func urlPathEscape(value string) string {
	const digits = "0123456789ABCDEF"
	var b strings.Builder
	for _, v := range []byte(value) {
		if v >= 'a' && v <= 'z' || v >= 'A' && v <= 'Z' || v >= '0' && v <= '9' || v == '-' || v == '.' || v == '_' {
			b.WriteByte(v)
		} else {
			b.WriteByte('%')
			b.WriteByte(digits[v>>4])
			b.WriteByte(digits[v&15])
		}
	}
	return b.String()
}
