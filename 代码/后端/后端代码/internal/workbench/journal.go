package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata"
	"unicode"
	"unicode/utf8"
)

const (
	journalImageMax = 8 * 1024 * 1024
	journalVideoMax = 16 * 1024 * 1024
	journalTotalMax = 32 * 1024 * 1024
	journalFileMax  = 8
	journalTextMax  = 20000
)

// Media bytes share the encrypted recovery point; API views explicitly strip them.
type JournalMedia struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	MIME       string `json:"mime"`
	Size       int    `json:"size"`
	DataBase64 string `json:"dataBase64,omitempty"`
}
type WorkLog struct {
	OwnerID   string         `json:"ownerId"`
	Date      string         `json:"date"`
	Text      string         `json:"text"`
	Media     []JournalMedia `json:"media"`
	Version   int            `json:"version"`
	UpdatedAt string         `json:"updatedAt"`
	Deleted   bool           `json:"deleted,omitempty"`
}
type journalDeleteInput struct {
	Version  int    `json:"version"`
	TimeZone string `json:"timeZone"`
}
type journalInput struct {
	Text     string   `json:"text"`
	MediaIDs []string `json:"mediaIds"`
	Version  int      `json:"version"`
	TimeZone string   `json:"timeZone"`
}
type journalMediaInput struct {
	Name       string `json:"name"`
	MIME       string `json:"mime"`
	DataBase64 string `json:"dataBase64"`
	Version    int    `json:"version"`
	TimeZone   string `json:"timeZone"`
}

// Invalid limits fail startup rather than silently increasing the upload boundary.
func journalMediaConfiguredLimit() (int, error) {
	value := os.Getenv("WB_JOURNAL_MEDIA_MAX_BYTES")
	if value == "" {
		return journalVideoMax, nil
	}
	n, err := strconv.Atoi(value)
	if err != nil || n < 1 || n > journalTotalMax {
		return 0, fmt.Errorf("WB_JOURNAL_MEDIA_MAX_BYTES must be within 1..%d", journalTotalMax)
	}
	return n, nil
}
func (s *Service) journalLimits() map[string]int {
	return map[string]int{"imageBytes": min(journalImageMax, s.journalMediaMax), "videoBytes": s.journalMediaMax, "totalBytes": journalTotalMax, "files": journalFileMax, "textChars": journalTextMax}
}
func personalLocation(value string) (*time.Location, error) {
	if value == "" {
		value = "Asia/Shanghai"
	}
	if len(value) > 100 || value == "Local" {
		return nil, fail(422, "invalid_time_zone", "请选择有效的 IANA 时区")
	}
	loc, err := time.LoadLocation(value)
	if err != nil {
		return nil, fail(422, "invalid_time_zone", "请选择有效的 IANA 时区")
	}
	return loc, nil
}
func validJournalDate(value string) bool {
	d, err := time.Parse("2006-01-02", value)
	return err == nil && len(value) == 10 && d.Format("2006-01-02") == value && d.Year() >= 1
}
func journalOwner(state *State, actor Actor, requested string, writing bool) (string, error) {
	if requested == "" {
		requested = actor.ID
	}
	if requested != actor.ID && (writing || actor.Role != "admin") {
		return "", fail(403, "private_work_log", "只能编辑本人日志；管理员查看他人日志为只读")
	}
	for _, account := range state.Accounts {
		if account.Actor.ID == requested {
			return requested, nil
		}
	}
	return "", fail(404, "not_found", "日志账户不存在或无访问权限")
}
func findWorkLog(state *State, owner, date string) *WorkLog {
	for i := range state.WorkLogs {
		if state.WorkLogs[i].OwnerID == owner && state.WorkLogs[i].Date == date {
			return &state.WorkLogs[i]
		}
	}
	return nil
}
func ensureWorkLog(state *State, owner, date string) *WorkLog {
	if entry := findWorkLog(state, owner, date); entry != nil {
		return entry
	}
	state.WorkLogs = append(state.WorkLogs, WorkLog{OwnerID: owner, Date: date, Media: []JournalMedia{}})
	return &state.WorkLogs[len(state.WorkLogs)-1]
}
func (s *Service) journalView(log WorkLog, actor Actor, loc *time.Location) map[string]any {
	media := make([]JournalMedia, 0, len(log.Media))
	for _, file := range log.Media {
		file.DataBase64 = ""
		media = append(media, file)
	}
	return map[string]any{"ownerId": log.OwnerID, "date": log.Date, "text": log.Text, "media": media, "version": log.Version, "updatedAt": log.UpdatedAt, "deleted": log.Deleted, "today": s.now().In(loc).Format("2006-01-02"), "timeZone": loc.String(), "readOnly": log.OwnerID != actor.ID, "limits": s.journalLimits()}
}
func (s *Service) readWorkLogs(w http.ResponseWriter, r *http.Request, actor Actor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	owner, err := journalOwner(&s.state, actor, r.URL.Query().Get("ownerId"), false)
	if err != nil {
		writeFailure(w, err)
		return
	}
	loc, err := personalLocation(r.URL.Query().Get("timeZone"))
	if err != nil {
		writeFailure(w, err)
		return
	}
	date := r.PathValue("date")
	if date != "" {
		if !validJournalDate(date) {
			writeFailure(w, fail(422, "invalid_date", "日志日期须为有效的 YYYY-MM-DD"))
			return
		}
		log := findWorkLog(&s.state, owner, date)
		if log == nil {
			log = &WorkLog{OwnerID: owner, Date: date, Media: []JournalMedia{}}
		}
		if owner != actor.ID {
			if err := s.auditLocked(actor, "work_log_read", owner+":"+date, "success"); err != nil {
				writeFailure(w, err)
				return
			}
		}
		writeJSON(w, 200, s.journalView(*log, actor, loc))
		return
	}
	scope := r.URL.Query().Get("scope")
	if scope == "all" {
		s.readAllWorkLogs(w, r, actor, owner, loc)
		return
	}
	if scope != "" {
		writeFailure(w, fail(422, "invalid_scope", "日志范围无效"))
		return
	}
	month := r.URL.Query().Get("month")
	if month == "" {
		month = s.now().In(loc).Format("2006-01")
	}
	parsed, err := time.Parse("2006-01", month)
	if err != nil || len(month) != 7 || parsed.Year() < 1 || parsed.Format("2006-01") != month {
		writeFailure(w, fail(422, "invalid_month", "月份须为有效的 YYYY-MM"))
		return
	}
	items := []map[string]any{}
	for _, log := range s.state.WorkLogs {
		if log.OwnerID == owner && !log.Deleted && strings.HasPrefix(log.Date, month+"-") {
			items = append(items, s.journalView(log, actor, loc))
		}
	}
	sort.Slice(items, func(i, j int) bool { return items[i]["date"].(string) < items[j]["date"].(string) })
	owners := []map[string]string{}
	if actor.Role == "admin" {
		for _, account := range s.state.Accounts {
			owners = append(owners, map[string]string{"id": account.Actor.ID, "name": account.Actor.Name, "role": account.Actor.Role})
		}
		if owner != actor.ID {
			if err := s.auditLocked(actor, "work_log_month_read", owner+":"+month, "success"); err != nil {
				writeFailure(w, err)
				return
			}
		}
	}
	writeJSON(w, 200, map[string]any{"ownerId": owner, "month": month, "today": s.now().In(loc).Format("2006-01-02"), "timeZone": loc.String(), "readOnly": owner != actor.ID, "items": items, "owners": owners, "limits": s.journalLimits()})
}

// The caller holds the state lock and has already checked the requested account.
func (s *Service) readAllWorkLogs(w http.ResponseWriter, r *http.Request, actor Actor, owner string, loc *time.Location) {
	page, pageSize := 1, 20
	var err error
	if value := r.URL.Query().Get("page"); value != "" {
		page, err = strconv.Atoi(value)
	}
	if err != nil || page < 1 || page > 1000000 {
		writeFailure(w, fail(422, "invalid_page", "日志页码无效"))
		return
	}
	if value := r.URL.Query().Get("pageSize"); value != "" {
		pageSize, err = strconv.Atoi(value)
	}
	if err != nil || pageSize < 1 || pageSize > 100 {
		writeFailure(w, fail(422, "invalid_page_size", "每页日志数量须为1—100"))
		return
	}
	logs := []*WorkLog{}
	for i := range s.state.WorkLogs {
		entry := &s.state.WorkLogs[i]
		if entry.OwnerID == owner && !entry.Deleted {
			logs = append(logs, entry)
		}
	}
	sort.Slice(logs, func(i, j int) bool { return logs[i].Date > logs[j].Date })
	start := min((page-1)*pageSize, len(logs))
	end := min(start+pageSize, len(logs))
	items := []map[string]any{}
	for _, entry := range logs[start:end] {
		items = append(items, s.journalView(*entry, actor, loc))
	}
	owners := []map[string]string{}
	if actor.Role == "admin" {
		for _, account := range s.state.Accounts {
			owners = append(owners, map[string]string{"id": account.Actor.ID, "name": account.Actor.Name, "role": account.Actor.Role})
		}
		if owner != actor.ID {
			if err := s.auditLocked(actor, "work_log_list_read", owner, "success"); err != nil {
				writeFailure(w, err)
				return
			}
		}
	}
	writeJSON(w, 200, map[string]any{"ownerId": owner, "scope": "all", "page": page, "pageSize": pageSize, "total": len(logs), "hasMore": end < len(logs), "today": s.now().In(loc).Format("2006-01-02"), "timeZone": loc.String(), "readOnly": owner != actor.ID, "items": items, "owners": owners, "limits": s.journalLimits()})
}

// Retain only the revision after deletion so old writes cannot resurrect a prior draft.
func (s *Service) deleteWorkLog(state *State, actor Actor, date string, input journalDeleteInput) (any, error) {
	if !validJournalDate(date) {
		return nil, fail(422, "invalid_date", "日志日期须为有效的 YYYY-MM-DD")
	}
	if _, err := personalLocation(input.TimeZone); err != nil {
		return nil, err
	}
	entry := findWorkLog(state, actor.ID, date)
	if entry == nil || entry.Deleted {
		return nil, fail(404, "not_found", "日志不存在或已删除")
	}
	if input.Version != entry.Version {
		return nil, fail(409, "version_conflict", "日志已更新，请重新加载核对后删除")
	}
	entry.Text, entry.Media, entry.Deleted = "", []JournalMedia{}, true
	entry.Version++
	entry.UpdatedAt = nowString(s.now())
	result := map[string]any{"ok": true, "ownerId": actor.ID, "date": date, "version": entry.Version, "deleted": true}
	cleared, err := json.Marshal(result)
	if err != nil {
		return nil, err
	}
	for key, request := range state.Requests {
		var ref struct {
			OwnerID string `json:"ownerId"`
			Date    string `json:"date"`
		}
		if json.Unmarshal(request.Body, &ref) == nil && ref.OwnerID == actor.ID && ref.Date == date {
			request.Body = append(json.RawMessage(nil), cleared...)
			state.Requests[key] = request
		}
	}
	s.appendAudit(state, actor, "work_log_delete", date, "success")
	return result, nil
}
func (s *Service) updateWorkLog(state *State, actor Actor, date string, input journalInput) (any, error) {
	loc, err := personalLocation(input.TimeZone)
	if err != nil {
		return nil, err
	}
	if !validJournalDate(date) || !utf8.ValidString(input.Text) || utf8.RuneCountInString(input.Text) > journalTextMax {
		return nil, fail(422, "invalid_work_log", "请检查日志日期及文字长度（最多20000字符）")
	}
	entry := ensureWorkLog(state, actor.ID, date)
	if input.Version != entry.Version {
		return nil, fail(409, "version_conflict", "日志已更新，请重新加载核对后保存")
	}
	if len(input.MediaIDs) > journalFileMax {
		return nil, fail(422, "media_limit", "每篇日志最多8个媒体文件")
	}
	files := make([]JournalMedia, 0, len(input.MediaIDs))
	seen := map[string]bool{}
	for _, id := range input.MediaIDs {
		if seen[id] {
			return nil, fail(422, "invalid_media", "附件不能重复")
		}
		seen[id] = true
		found := false
		for _, media := range entry.Media {
			if media.ID == id {
				files = append(files, media)
				found = true
				break
			}
		}
		if !found {
			return nil, fail(404, "not_found", "附件不存在或不属于本人这篇日志")
		}
	}
	entry.Text, entry.Media, entry.Version, entry.UpdatedAt = input.Text, files, entry.Version+1, nowString(s.now())
	entry.Deleted = false
	s.appendAudit(state, actor, "work_log_save", date, "success")
	return s.journalView(*entry, actor, loc), nil
}
func validJournalMedia(name, mime string, data []byte) error {
	if !validPersonalText(name, 1, 180) || strings.ContainsAny(name, "/\\") || strings.IndexFunc(name, unicode.IsControl) >= 0 {
		return fail(422, "invalid_media_name", "请使用不含路径或控制字符的文件名（最多180字符）")
	}
	valid := false
	switch mime {
	case "image/png", "image/jpeg", "image/gif":
		cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
		valid = err == nil && cfg.Width > 0 && cfg.Height > 0 && cfg.Width <= 16384 && cfg.Height <= 16384 && int64(cfg.Width)*int64(cfg.Height) <= 64000000 && http.DetectContentType(data) == mime
	case "image/webp":
		valid = len(data) >= 16 && string(data[:4]) == "RIFF" && string(data[8:12]) == "WEBP" && http.DetectContentType(data) == mime
	case "video/mp4":
		valid = len(data) >= 16 && string(data[4:8]) == "ftyp" && string(data[8:12]) != "qt  "
	case "video/quicktime":
		valid = len(data) >= 16 && string(data[4:8]) == "ftyp" && string(data[8:12]) == "qt  "
	case "video/webm":
		valid = len(data) >= 16 && bytes.HasPrefix(data, []byte{0x1a, 0x45, 0xdf, 0xa3}) && bytes.Contains(data[:min(len(data), 512)], []byte("webm"))
	}
	if !valid {
		return fail(422, "unsupported_media", "文件内容与类型不匹配；支持PNG/JPEG/GIF/WebP和MP4/WebM/QuickTime")
	}
	return nil
}
func (s *Service) appendJournalMedia(state *State, actor Actor, date string, input journalMediaInput) (any, error) {
	loc, err := personalLocation(input.TimeZone)
	if err != nil {
		return nil, err
	}
	if !validJournalDate(date) {
		return nil, fail(422, "invalid_date", "日志日期须为有效的 YYYY-MM-DD")
	}
	limit := s.journalMediaMax
	if strings.HasPrefix(input.MIME, "image/") {
		limit = min(limit, journalImageMax)
	}
	if len(input.DataBase64) > base64.StdEncoding.EncodedLen(limit) {
		return nil, fail(413, "media_too_large", "媒体文件超过本次允许的大小")
	}
	data, err := base64.StdEncoding.Strict().DecodeString(input.DataBase64)
	if err != nil || len(data) == 0 {
		return nil, fail(422, "invalid_media", "媒体内容为空或Base64无效")
	}
	if len(data) > limit {
		return nil, fail(413, "media_too_large", "媒体文件超过本次允许的大小")
	}
	if err := validJournalMedia(input.Name, input.MIME, data); err != nil {
		return nil, err
	}
	entry := ensureWorkLog(state, actor.ID, date)
	if input.Version != entry.Version {
		return nil, fail(409, "version_conflict", "日志已更新，请重新加载核对后上传")
	}
	total := len(data)
	for _, media := range entry.Media {
		total += media.Size
	}
	if len(entry.Media) >= journalFileMax || total > journalTotalMax {
		return nil, fail(413, "media_limit", "每篇日志最多8个附件、合计32MiB")
	}
	entry.Media = append(entry.Media, JournalMedia{ID: randomID("journal_media_"), Name: input.Name, MIME: input.MIME, Size: len(data), DataBase64: input.DataBase64})
	entry.Version++
	entry.UpdatedAt = nowString(s.now())
	entry.Deleted = false
	s.appendAudit(state, actor, "work_log_media_add", date, "success")
	return s.journalView(*entry, actor, loc), nil
}
func (s *Service) downloadJournalMedia(w http.ResponseWriter, r *http.Request, actor Actor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	for _, log := range s.state.WorkLogs {
		if log.OwnerID != actor.ID && actor.Role != "admin" {
			continue
		}
		for _, media := range log.Media {
			if media.ID != r.PathValue("id") {
				continue
			}
			if err := s.auditLocked(actor, "work_log_media_read", log.OwnerID+":"+log.Date, "success", media.ID); err != nil {
				writeFailure(w, err)
				return
			}
			writeJSON(w, 200, map[string]any{"id": media.ID, "ownerId": log.OwnerID, "date": log.Date, "name": media.Name, "mime": media.MIME, "size": media.Size, "dataBase64": media.DataBase64})
			return
		}
	}
	writeFailure(w, fail(404, "not_found", "媒体不存在或无访问权限"))
}

// The larger JSON body applies only to authenticated media uploads, including Base64 overhead.
func (s *Service) writeJournalMedia(w http.ResponseWriter, r *http.Request, actor Actor) {
	r.Body = http.MaxBytesReader(w, r.Body, int64(base64.StdEncoding.EncodedLen(s.journalMediaMax)+4096))
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		writeFailure(w, fail(413, "body_too_large", "媒体请求体超过允许大小"))
		return
	}
	response, status, err := s.transact(actor, r.Method+" "+r.URL.Path, r.Header.Get("Idempotency-Key"), raw, 200, func(state *State) (any, error) {
		if _, err := journalOwner(state, actor, r.URL.Query().Get("ownerId"), true); err != nil {
			return nil, err
		}
		var input journalMediaInput
		if err := decodeStrict(raw, &input); err != nil {
			return nil, err
		}
		return s.appendJournalMedia(state, actor, r.PathValue("date"), input)
	})
	if err != nil {
		writeFailure(w, err)
		return
	}
	writeJSON(w, status, json.RawMessage(response))
}
