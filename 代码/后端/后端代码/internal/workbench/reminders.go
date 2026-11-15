package workbench

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"
	"unicode/utf8"
)

type PersonalReminder struct {
	ID         string `json:"id"`
	OwnerID    string `json:"ownerId"`
	Title      string `json:"title"`
	Body       string `json:"body"`
	DueAt      string `json:"dueAt"`
	TimeZone   string `json:"timeZone"`
	Status     string `json:"status"`
	Version    int    `json:"version"`
	CreatedAt  string `json:"createdAt"`
	UpdatedAt  string `json:"updatedAt"`
	NotifiedAt string `json:"notifiedAt,omitempty"`
}
type reminderInput struct {
	Title    string `json:"title"`
	Body     string `json:"body"`
	DueAt    string `json:"dueAt"`
	TimeZone string `json:"timeZone"`
	Status   string `json:"status"`
	Version  int    `json:"version"`
}
type personalVersion struct {
	Version int `json:"version"`
}

// Every private route uses the same bearer/session gate as the business API.
func (s *Service) registerPersonalRoutes(protected func(string, func(http.ResponseWriter, *http.Request, Actor))) {
	protected("GET /api/v38/work-logs", s.readWorkLogs)
	protected("GET /api/v38/work-logs/{date}", s.readWorkLogs)
	protected("GET /api/v38/work-log-media/{id}", s.downloadJournalMedia)
	protected("DELETE /api/v38/work-logs/{date}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input journalDeleteInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.deleteWorkLog(state, actor, r.PathValue("date"), input)
		})
	})
	protected("PUT /api/v38/work-logs/{date}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input journalInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.updateWorkLog(state, actor, r.PathValue("date"), input)
		})
	})
	protected("POST /api/v38/work-logs/{date}/media", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if ownPersonalWrite(w, r, actor) {
			s.writeJournalMedia(w, r, actor)
		}
	})
	protected("GET /api/v38/reminders", s.readReminders)
	protected("POST /api/v38/reminders", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 201, func(state *State, raw []byte) (any, error) {
			var input reminderInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.saveReminder(state, actor, "", input)
		})
	})
	protected("PUT /api/v38/reminders/{id}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input reminderInput
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.saveReminder(state, actor, r.PathValue("id"), input)
		})
	})
	protected("DELETE /api/v38/reminders/{id}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input personalVersion
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			for i, reminder := range state.Reminders {
				if reminder.ID != r.PathValue("id") || reminder.OwnerID != actor.ID {
					continue
				}
				if input.Version != reminder.Version {
					return nil, fail(409, "version_conflict", "提醒已更新，请重新加载核对后取消")
				}
				state.Reminders = append(state.Reminders[:i], state.Reminders[i+1:]...)
				s.appendAudit(state, actor, "reminder_delete", reminder.ID, "success")
				return map[string]any{"ok": true, "id": reminder.ID, "ownerId": actor.ID}, nil
			}
			return nil, fail(404, "not_found", "提醒不存在或无访问权限")
		})
	})
	protected("POST /api/v38/reminders/{id}/fire", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		if !ownPersonalWrite(w, r, actor) {
			return
		}
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			var input personalVersion
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			return s.fireReminder(state, actor, r.PathValue("id"), input.Version)
		})
	})
}
func ownPersonalWrite(w http.ResponseWriter, r *http.Request, actor Actor) bool {
	if owner := r.URL.Query().Get("ownerId"); owner != "" && owner != actor.ID {
		writeFailure(w, fail(403, "private_work_log", "只能修改本人日志和提醒；管理员查看他人日志为只读"))
		return false
	}
	return true
}
func validPersonalText(value string, minimum, maximum int) bool {
	return utf8.ValidString(value) && utf8.RuneCountInString(value) <= maximum && (minimum == 0 || utf8.RuneCountInString(strings.TrimSpace(value)) >= minimum)
}
func normalizeReminderInput(input reminderInput) (reminderInput, error) {
	if !validPersonalText(input.Title, 1, 200) || !validPersonalText(input.Body, 0, 2000) {
		return input, fail(422, "invalid_reminder", "提醒标题需1—200字符，正文最多2000字符")
	}
	loc, err := personalLocation(input.TimeZone)
	if err != nil {
		return input, err
	}
	due, err := time.Parse(time.RFC3339Nano, input.DueAt)
	if err != nil || due.Year() < 1 || due.Year() > 9999 {
		return input, fail(422, "invalid_reminder_time", "提醒时间须为含时区的有效ISO时间")
	}
	input.DueAt, input.TimeZone = due.UTC().Format(time.RFC3339Nano), loc.String()
	return input, nil
}
func (s *Service) readReminders(w http.ResponseWriter, r *http.Request, actor Actor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	if !ownPersonalWrite(w, r, actor) {
		return
	}
	items := []PersonalReminder{}
	for _, reminder := range s.state.Reminders {
		if reminder.OwnerID == actor.ID {
			items = append(items, reminder)
		}
	}
	sort.Slice(items, func(i, j int) bool {
		left, _ := time.Parse(time.RFC3339Nano, items[i].DueAt)
		right, _ := time.Parse(time.RFC3339Nano, items[j].DueAt)
		if left.Equal(right) {
			return items[i].ID < items[j].ID
		}
		return left.Before(right)
	})
	writeJSON(w, 200, map[string]any{"items": items, "serverNow": nowString(s.now())})
}
func (s *Service) saveReminder(state *State, actor Actor, id string, input reminderInput) (any, error) {
	input, err := normalizeReminderInput(input)
	if err != nil {
		return nil, err
	}
	if id == "" {
		if input.Version != 0 || (input.Status != "" && input.Status != "pending") {
			return nil, fail(422, "invalid_reminder", "新提醒只能从待提醒状态创建")
		}
		now := nowString(s.now())
		reminder := PersonalReminder{ID: randomID("reminder_"), OwnerID: actor.ID, Title: input.Title, Body: input.Body, DueAt: input.DueAt, TimeZone: input.TimeZone, Status: "pending", Version: 1, CreatedAt: now, UpdatedAt: now}
		state.Reminders = append(state.Reminders, reminder)
		s.appendAudit(state, actor, "reminder_create", reminder.ID, "success")
		return reminder, nil
	}
	for i := range state.Reminders {
		reminder := &state.Reminders[i]
		if reminder.ID != id || reminder.OwnerID != actor.ID {
			continue
		}
		if input.Version != reminder.Version {
			return nil, fail(409, "version_conflict", "提醒已更新，请重新加载核对后保存")
		}
		if input.Status != "pending" && input.Status != "notified" && input.Status != "done" {
			return nil, fail(422, "invalid_reminder_status", "请选择待提醒、已提醒或已完成状态")
		}
		if input.DueAt != reminder.DueAt {
			reminder.Status, reminder.NotifiedAt = "pending", ""
		} else {
			if input.Status == "pending" && reminder.Status != "pending" {
				return nil, fail(422, "reminder_time_required", "再次提醒请明确修改提醒时间")
			}
			if input.Status == "notified" && reminder.Status != "notified" {
				return nil, fail(422, "invalid_reminder_status", "已提醒状态由到期提醒触发，不能手工伪造")
			}
			reminder.Status = input.Status
		}
		reminder.Title, reminder.Body, reminder.DueAt, reminder.TimeZone = input.Title, input.Body, input.DueAt, input.TimeZone
		reminder.Version++
		reminder.UpdatedAt = nowString(s.now())
		s.appendAudit(state, actor, "reminder_update", reminder.ID, "success")
		return *reminder, nil
	}
	return nil, fail(404, "not_found", "提醒不存在或无访问权限")
}

// Claiming and its persisted state transition share the business transaction mutex.
func (s *Service) fireReminder(state *State, actor Actor, id string, version int) (any, error) {
	for i := range state.Reminders {
		reminder := &state.Reminders[i]
		if reminder.ID != id || reminder.OwnerID != actor.ID {
			continue
		}
		due, err := time.Parse(time.RFC3339Nano, reminder.DueAt)
		if err != nil {
			return nil, fmt.Errorf("invalid persisted reminder time")
		}
		claimed := reminder.Status == "pending" && reminder.Version == version && !due.After(s.now())
		if claimed {
			reminder.Status, reminder.NotifiedAt = "notified", nowString(s.now())
			reminder.UpdatedAt = reminder.NotifiedAt
			reminder.Version++
			s.appendAudit(state, actor, "reminder_fire", reminder.ID, "success")
		}
		return map[string]any{"claimed": claimed, "reminder": *reminder}, nil
	}
	return nil, fail(404, "not_found", "提醒不存在或无访问权限")
}
func personalWritePath(path string) bool {
	for _, prefix := range []string{"PUT /api/v38/work-logs/", "POST /api/v38/work-logs/", "DELETE /api/v38/work-logs/", "POST /api/v38/reminders", "PUT /api/v38/reminders/", "DELETE /api/v38/reminders/"} {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}

// Personal writes can only produce the caller's own metadata, never media bytes.
func (s *Service) replayPersonalRequest(actor Actor, path string, request CachedRequest) (json.RawMessage, int, error) {
	var result struct {
		OwnerID  string            `json:"ownerId"`
		Date     string            `json:"date"`
		Version  int               `json:"version"`
		TimeZone string            `json:"timeZone"`
		Reminder *PersonalReminder `json:"reminder"`
	}
	if err := json.Unmarshal(request.Body, &result); err != nil {
		return nil, 0, err
	}
	owner := result.OwnerID
	if result.Reminder != nil {
		owner = result.Reminder.OwnerID
	}
	if owner != actor.ID {
		return nil, 0, fail(404, "not_found", "原请求不属于本人")
	}
	if result.Date != "" {
		entry := findWorkLog(&s.state, actor.ID, result.Date)
		if strings.HasPrefix(path, "DELETE /api/v38/work-logs/") {
			if entry == nil || !entry.Deleted || entry.Version != result.Version {
				return nil, 0, fail(409, "version_conflict", "日志已更新，请重新加载核对后删除")
			}
		} else {
			if entry == nil || entry.Deleted {
				return nil, 0, fail(404, "not_found", "日志不存在或已删除")
			}
			loc, err := personalLocation(result.TimeZone)
			if err != nil {
				return nil, 0, err
			}
			body, err := json.Marshal(s.journalView(*entry, actor, loc))
			return body, request.Status, err
		}
	}
	return append(json.RawMessage(nil), request.Body...), request.Status, nil
}
