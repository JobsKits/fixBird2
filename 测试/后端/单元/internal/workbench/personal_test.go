package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func personalHTTP(t *testing.T, s *Service, actorID, method, path, key string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var raw []byte
	if body != nil {
		raw, _ = json.Marshal(body)
	}
	r := httptest.NewRequest(method, "/api/v38"+path, bytes.NewReader(raw))
	if actorID != "" {
		token := "personal-test-" + actorID
		s.mu.Lock()
		if _, exists := s.sessions[token]; !exists {
			s.sessions[token] = session{Actor: testActor(s, actorID), ExpiresAt: s.now().Add(24 * time.Hour)}
		}
		s.mu.Unlock()
		r.Header.Set("Authorization", "Bearer "+token)
	}
	if method != "GET" {
		if key == "" {
			key = randomID("key_")
		}
		r.Header.Set("Idempotency-Key", key)
	}
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}
func personalValue(t *testing.T, w *httptest.ResponseRecorder, status int) map[string]any {
	t.Helper()
	if w.Code != status {
		t.Fatalf("status=%d want=%d body=%s", w.Code, status, w.Body.String())
	}
	var value map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &value); err != nil {
		t.Fatal(err)
	}
	return value
}
func journalBody(text string, version int, media ...string) map[string]any {
	return map[string]any{"text": text, "version": version, "mediaIds": media, "timeZone": "Asia/Shanghai"}
}
func testJournalPNG(t *testing.T) string {
	t.Helper()
	var data bytes.Buffer
	if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, 2, 2))); err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(data.Bytes())
}
func TestPersonalJournalOwnershipHistoryAndVersions(t *testing.T) {
	s, _ := testService(t)
	s.now = func() time.Time { return time.Date(2026, 11, 13, 17, 30, 0, 0, time.UTC) }
	raw := personalHTTP(t, s, "customer", "PUT", "/work-logs/2024-02-29", "journal-save", journalBody("私密历史<script>alert(1)</script>", 0))
	entry := personalValue(t, raw, 200)
	if entry["ownerId"] != "customer" || entry["version"] != float64(1) || entry["today"] != "2026-11-14" {
		t.Fatal(entry)
	}
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2024-02-29", "journal-save", journalBody("私密历史<script>alert(1)</script>", 0)), 200)
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2024-02-29", "journal-save", journalBody("变更内容", 0)), 409)
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2024-02-29", "", journalBody("不能覆盖新版本", 0)), 409)
	for _, actor := range []string{"customer-peer", "customer-b", "engineer"} {
		personalValue(t, personalHTTP(t, s, actor, "GET", "/work-logs?month=2024-02&ownerId=customer", "", nil), 403)
		personalValue(t, personalHTTP(t, s, actor, "GET", "/work-logs/2024-02-29?ownerId=customer", "", nil), 403)
		own := personalValue(t, personalHTTP(t, s, actor, "GET", "/work-logs?month=2024-02", "", nil), 200)
		if len(own["items"].([]any)) != 0 || len(own["owners"].([]any)) != 0 {
			t.Fatal("private calendar leaked", own)
		}
	}
	admin := personalValue(t, personalHTTP(t, s, "admin", "GET", "/work-logs/2024-02-29?ownerId=customer", "", nil), 200)
	if admin["readOnly"] != true || admin["text"] != entry["text"] {
		t.Fatal(admin)
	}
	personalValue(t, personalHTTP(t, s, "admin", "PUT", "/work-logs/2024-02-29?ownerId=customer", "", journalBody("越权写入", 1)), 403)
	personalValue(t, personalHTTP(t, s, "admin", "PUT", "/work-logs/2024-02-29", "", map[string]any{"ownerId": "customer", "text": "越权", "version": 1}), 422)
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2030-01-01", "", journalBody("预记", 0)), 200)
	personalValue(t, personalHTTP(t, s, "customer", "GET", "/work-logs/2023-02-29", "", nil), 422)
	personalValue(t, personalHTTP(t, s, "customer", "GET", "/work-logs?month=2026-13", "", nil), 422)
	personalValue(t, personalHTTP(t, s, "customer", "GET", "/work-logs?timeZone=Local", "", nil), 422)
	personalValue(t, personalHTTP(t, s, "", "GET", "/work-logs", "", nil), 401)
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2026-11-14", "", journalBody(strings.Repeat("字", journalTextMax+1), 0)), 422)
}
func TestPersonalJournalMediaPrivateAndAtomic(t *testing.T) {
	s, p := testService(t)
	encoded := testJournalPNG(t)
	input := map[string]any{"name": "粘贴.png", "mime": "image/png", "dataBase64": encoded, "version": 0, "timeZone": "Asia/Shanghai"}
	entry := personalValue(t, personalHTTP(t, s, "engineer", "POST", "/work-logs/2026-11-14/media", "media-once", input), 200)
	id := entry["media"].([]any)[0].(map[string]any)["id"].(string)
	if bytes.Contains(mustJSON(t, entry), []byte("dataBase64")) {
		t.Fatal("list returned private media bytes")
	}
	personalValue(t, personalHTTP(t, s, "engineer", "POST", "/work-logs/2026-11-14/media", "media-once", input), 200)
	if len(s.state.WorkLogs[0].Media) != 1 {
		t.Fatal("upload replay duplicated media")
	}
	for _, who := range []string{"engineer", "admin"} {
		media := personalValue(t, personalHTTP(t, s, who, "GET", "/work-log-media/"+id, "", nil), 200)
		if media["dataBase64"] != encoded || media["ownerId"] != "engineer" || media["date"] != "2026-11-14" {
			t.Fatal(media)
		}
	}
	personalValue(t, personalHTTP(t, s, "customer", "GET", "/work-log-media/"+id, "", nil), 404)
	personalValue(t, personalHTTP(t, s, "", "GET", "/work-log-media/"+id, "", nil), 401)
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/work-logs/2026-11-14/media?ownerId=engineer", "", input), 403)
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-13", "", journalBody("跨日期不能引用", 0, id)), 404)
	bad := map[string]any{"name": "假图.png", "mime": "image/png", "dataBase64": base64.StdEncoding.EncodeToString([]byte("<script>evil</script>")), "version": 1}
	personalValue(t, personalHTTP(t, s, "engineer", "POST", "/work-logs/2026-11-14/media", "", bad), 422)
	p.fail = true
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-14", "", journalBody("失败不提交", 1)), 500)
	p.fail = false
	if len(s.state.WorkLogs[0].Media) != 1 || s.state.WorkLogs[0].Version != 1 {
		t.Fatal("partial media deletion on failed save")
	}
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-14", "", journalBody("移除文件", 1)), 200)
	personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-log-media/"+id, "", nil), 404)
	t.Setenv("WB_JOURNAL_MEDIA_MAX_BYTES", "4")
	limited, _ := testService(t)
	personalValue(t, personalHTTP(t, limited, "engineer", "POST", "/work-logs/2026-11-14/media", "", input), 413)
}
func TestPersonalJournalAllHistoryPaginationAndPrivacy(t *testing.T) {
	s, _ := testService(t)
	for _, date := range []string{"2024-02-29", "2026-11-14", "2026-01-02"} {
		personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/"+date, "", journalBody(date, 0)), 200)
	}
	personalValue(t, personalHTTP(t, s, "admin", "PUT", "/work-logs/2026-11-15", "", journalBody("admin private", 0)), 200)
	page := personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-logs?scope=all&pageSize=2", "", nil), 200)
	items := page["items"].([]any)
	if page["total"] != float64(3) || page["hasMore"] != true || len(items) != 2 || items[0].(map[string]any)["date"] != "2026-11-14" || items[1].(map[string]any)["date"] != "2026-01-02" {
		t.Fatal(page)
	}
	page = personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-logs?scope=all&pageSize=2&page=2", "", nil), 200)
	if page["hasMore"] != false || len(page["items"].([]any)) != 1 || page["items"].([]any)[0].(map[string]any)["date"] != "2024-02-29" {
		t.Fatal(page)
	}
	page = personalValue(t, personalHTTP(t, s, "admin", "GET", "/work-logs?scope=all&ownerId=engineer&page=100", "", nil), 200)
	if page["readOnly"] != true || page["total"] != float64(3) || len(page["items"].([]any)) != 0 || len(page["owners"].([]any)) == 0 {
		t.Fatal(page)
	}
	for _, who := range []string{"customer", "customer-peer", "warehouse"} {
		personalValue(t, personalHTTP(t, s, who, "GET", "/work-logs?scope=all&ownerId=engineer", "", nil), 403)
	}
	for _, query := range []string{"scope=unknown", "scope=all&page=0", "scope=all&page=1000001", "scope=all&page=bad", "scope=all&pageSize=0", "scope=all&pageSize=101"} {
		personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-logs?"+query, "", nil), 422)
	}
	personalValue(t, personalHTTP(t, s, "", "GET", "/work-logs?scope=all", "", nil), 401)
}
func TestPersonalJournalDeleteAtomicMediaAndStaleRequests(t *testing.T) {
	s, p := testService(t)
	encoded := testJournalPNG(t)
	media := map[string]any{"name": "原件.png", "mime": "image/png", "dataBase64": encoded, "version": 0, "timeZone": "Asia/Shanghai"}
	created := personalValue(t, personalHTTP(t, s, "engineer", "POST", "/work-logs/2026-11-14/media", "journal-media", media), 200)
	id := created["media"].([]any)[0].(map[string]any)["id"].(string)
	privateText := "删除后不能由旧请求重新显示的私密内容"
	body := journalBody(privateText, 1, id)
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-14", "journal-before-delete", body), 200)
	deletion := map[string]any{"version": 2, "timeZone": "Asia/Shanghai"}
	personalValue(t, personalHTTP(t, s, "admin", "DELETE", "/work-logs/2026-11-14?ownerId=engineer", "", deletion), 403)
	personalValue(t, personalHTTP(t, s, "customer", "DELETE", "/work-logs/2026-11-14", "", deletion), 404)
	personalValue(t, personalHTTP(t, s, "", "DELETE", "/work-logs/2026-11-14", "", deletion), 401)
	personalValue(t, personalHTTP(t, s, "engineer", "DELETE", "/work-logs/2026-11-14", "", map[string]int{"version": 1}), 409)
	p.fail = true
	personalValue(t, personalHTTP(t, s, "engineer", "DELETE", "/work-logs/2026-11-14", "delete-once", deletion), 500)
	p.fail = false
	personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-log-media/"+id, "", nil), 200)
	if entry := findWorkLog(&s.state, "engineer", "2026-11-14"); entry.Deleted || entry.Version != 2 || entry.Text != privateText {
		t.Fatal("failed delete changed original", entry)
	}
	deleted := personalValue(t, personalHTTP(t, s, "engineer", "DELETE", "/work-logs/2026-11-14", "delete-once", deletion), 200)
	if deleted["deleted"] != true || deleted["version"] != float64(3) {
		t.Fatal(deleted)
	}
	personalValue(t, personalHTTP(t, s, "engineer", "DELETE", "/work-logs/2026-11-14", "delete-once", deletion), 200)
	personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-log-media/"+id, "", nil), 404)
	personalValue(t, personalHTTP(t, s, "admin", "GET", "/work-log-media/"+id, "", nil), 404)
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-14", "journal-before-delete", body), 404)
	personalValue(t, personalHTTP(t, s, "engineer", "POST", "/work-logs/2026-11-14/media", "journal-media", media), 404)
	if bytes.Contains(mustJSON(t, s.state.Requests), []byte(privateText)) || bytes.Contains(mustJSON(t, s.state.WorkLogs), []byte(encoded)) {
		t.Fatal("private content retained after delete")
	}
	for _, query := range []string{"?scope=all", "?month=2026-11"} {
		page := personalValue(t, personalHTTP(t, s, "engineer", "GET", "/work-logs"+query, "", nil), 200)
		if len(page["items"].([]any)) != 0 {
			t.Fatal("deleted entry remained listed", page)
		}
	}
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	entry := personalValue(t, personalHTTP(t, restarted, "engineer", "GET", "/work-logs/2026-11-14", "", nil), 200)
	if entry["deleted"] != true || entry["text"] != "" || entry["version"] != float64(3) || len(entry["media"].([]any)) != 0 {
		t.Fatal(entry)
	}
	personalValue(t, personalHTTP(t, restarted, "engineer", "PUT", "/work-logs/2026-11-14", "", journalBody("不能复活旧写入", 2)), 409)
	newEntry := personalValue(t, personalHTTP(t, restarted, "engineer", "PUT", "/work-logs/2026-11-14", "journal-recreated", journalBody("新记录", 3)), 200)
	if newEntry["deleted"] != false || newEntry["version"] != float64(4) {
		t.Fatal(newEntry)
	}
	personalValue(t, personalHTTP(t, restarted, "engineer", "DELETE", "/work-logs/2026-11-14", "delete-once", deletion), 409)
	replayed := personalValue(t, personalHTTP(t, restarted, "engineer", "PUT", "/work-logs/2026-11-14", "journal-before-delete", body), 200)
	if replayed["text"] != "新记录" || replayed["version"] != float64(4) {
		t.Fatal("old request replay exposed deleted text", replayed)
	}
}
func TestPersonalJournalDeleteAndSaveSerialize(t *testing.T) {
	s, _ := testService(t)
	personalValue(t, personalHTTP(t, s, "engineer", "PUT", "/work-logs/2026-11-14", "", journalBody("原记录", 0)), 200)
	results := make(chan int, 2)
	var wg sync.WaitGroup
	for _, method := range []string{"PUT", "DELETE"} {
		wg.Add(1)
		go func(method string) {
			defer wg.Done()
			var body any = journalBody("并发更新", 1)
			if method == "DELETE" {
				body = map[string]int{"version": 1}
			}
			results <- personalHTTP(t, s, "engineer", method, "/work-logs/2026-11-14", "", body).Code
		}(method)
	}
	wg.Wait()
	close(results)
	statuses := map[int]int{}
	for code := range results {
		statuses[code]++
	}
	if statuses[200] != 1 || statuses[409] != 1 {
		t.Fatal(statuses)
	}
	if entry := findWorkLog(&s.state, "engineer", "2026-11-14"); entry.Version != 2 {
		t.Fatal(entry)
	}
}
func mustJSON(t *testing.T, v any) []byte {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return data
}
func reminderBody(title, due string) map[string]any {
	return map[string]any{"title": title, "body": "事件内容", "dueAt": due, "timeZone": "Asia/Shanghai"}
}
func TestPersonalReminderConcurrentClaimOwnershipAndRestart(t *testing.T) {
	s, p := testService(t)
	now := time.Date(2026, 11, 14, 2, 0, 0, 0, time.UTC)
	s.now = func() time.Time { return now }
	created := personalValue(t, personalHTTP(t, s, "engineer", "POST", "/reminders", "create-event", reminderBody("到时处理", now.Add(-time.Minute).Format(time.RFC3339))), 201)
	id := created["id"].(string)
	personalValue(t, personalHTTP(t, s, "engineer", "POST", "/reminders", "create-event", reminderBody("到时处理", now.Add(-time.Minute).Format(time.RFC3339))), 201)
	for _, who := range []string{"admin", "customer", "customer-peer"} {
		personalValue(t, personalHTTP(t, s, who, "GET", "/reminders?ownerId=engineer", "", nil), 403)
		personalValue(t, personalHTTP(t, s, who, "POST", "/reminders/"+id+"/fire", "", map[string]int{"version": 1}), 404)
		personalValue(t, personalHTTP(t, s, who, "DELETE", "/reminders/"+id, "", map[string]int{"version": 1}), 404)
	}
	var wg sync.WaitGroup
	results := make(chan bool, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			w := personalHTTP(t, s, "engineer", "POST", "/reminders/"+id+"/fire", "", map[string]int{"version": 1})
			result := personalValue(t, w, 200)
			results <- result["claimed"].(bool)
		}()
	}
	wg.Wait()
	close(results)
	claims := 0
	for claimed := range results {
		if claimed {
			claims++
		}
	}
	if claims != 1 {
		t.Fatalf("claims=%d", claims)
	}
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	restarted.now = s.now
	response := personalValue(t, personalHTTP(t, restarted, "engineer", "POST", "/reminders/"+id+"/fire", "", map[string]int{"version": 2}), 200)
	if response["claimed"] != false {
		t.Fatal("restart re-fired notified event")
	}
	edit := reminderBody("调整时间", now.Add(time.Hour).Format(time.RFC3339))
	edit["version"] = 2
	edit["status"] = "notified"
	updated := personalValue(t, personalHTTP(t, restarted, "engineer", "PUT", "/reminders/"+id, "", edit), 200)
	if updated["status"] != "pending" || updated["version"] != float64(3) {
		t.Fatal(updated)
	}
	response = personalValue(t, personalHTTP(t, restarted, "engineer", "POST", "/reminders/"+id+"/fire", "", map[string]int{"version": 3}), 200)
	if response["claimed"] != false {
		t.Fatal("future reminder fired")
	}
	edit["version"] = 3
	edit["status"] = "done"
	personalValue(t, personalHTTP(t, restarted, "engineer", "PUT", "/reminders/"+id, "", edit), 200)
	now = now.Add(2 * time.Hour)
	response = personalValue(t, personalHTTP(t, restarted, "engineer", "POST", "/reminders/"+id+"/fire", "", map[string]int{"version": 4}), 200)
	if response["claimed"] != false {
		t.Fatal("completed reminder fired")
	}
	personalValue(t, personalHTTP(t, restarted, "engineer", "DELETE", "/reminders/"+id, "", map[string]int{"version": 3}), 409)
	personalValue(t, personalHTTP(t, restarted, "engineer", "DELETE", "/reminders/"+id, "delete-reminder", map[string]int{"version": 4}), 200)
	personalValue(t, personalHTTP(t, restarted, "engineer", "DELETE", "/reminders/"+id, "delete-reminder", map[string]int{"version": 4}), 200)
}
func TestPersonalEncryptedFileRestartAndRevocation(t *testing.T) {
	dir := t.TempDir()
	key := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(filepath.Join(dir, "data"), key)
	if err != nil {
		t.Fatal(err)
	}
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	personalValue(t, personalHTTP(t, s, "customer", "PUT", "/work-logs/2026-11-14", "", journalBody("不可出现明文秘密", 0)), 200)
	media := map[string]any{"name": "测试.png", "mime": "image/png", "dataBase64": testJournalPNG(t), "version": 1}
	entry := personalValue(t, personalHTTP(t, s, "customer", "POST", "/work-logs/2026-11-14/media", "", media), 200)
	id := entry["media"].([]any)[0].(map[string]any)["id"].(string)
	encrypted, err := os.ReadFile(filepath.Join(dir, "data", "snapshot.enc"))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encrypted, []byte("不可出现明文秘密")) || bytes.Contains(encrypted, []byte(media["dataBase64"].(string))) {
		t.Fatal("journal stored outside encryption")
	}
	if err := p.Close(); err != nil {
		t.Fatal(err)
	}
	p, err = NewFilePersistence(filepath.Join(dir, "data"), key)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	got := personalValue(t, personalHTTP(t, restarted, "customer", "GET", "/work-logs/2026-11-14?timeZone="+url.QueryEscape("America/New_York"), "", nil), 200)
	if got["text"] != "不可出现明文秘密" || got["version"] != float64(2) {
		t.Fatal(got)
	}
	personalValue(t, personalHTTP(t, restarted, "customer", "GET", "/work-log-media/"+id, "", nil), 200)
	restarted.mu.Lock()
	for i := range restarted.state.Accounts {
		if restarted.state.Accounts[i].Actor.ID == "customer" {
			restarted.state.Accounts[i].Actor.Status = "disabled"
			restarted.state.Accounts[i].Actor.AuthVersion++
		}
	}
	restarted.mu.Unlock()
	w := personalHTTP(t, restarted, "customer", "GET", "/work-log-media/"+id, "", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("revoked download status=%d", w.Code)
	}
}

func TestPersonalReminderFailureAndDSTInstants(t *testing.T) {
	s, p := testService(t)
	now := time.Date(2026, 11, 1, 5, 45, 0, 0, time.UTC)
	s.now = func() time.Time { return now }
	first := reminderBody("夏令时第一次01:30", "2026-11-01T01:30:00-04:00")
	first["timeZone"] = "America/New_York"
	second := reminderBody("标准时第二次01:30", "2026-11-01T01:30:00-05:00")
	second["timeZone"] = "America/New_York"
	a := personalValue(t, personalHTTP(t, s, "customer", "POST", "/reminders", "", first), 201)
	b := personalValue(t, personalHTTP(t, s, "customer", "POST", "/reminders", "", second), 201)
	if a["dueAt"] != "2026-11-01T05:30:00Z" || b["dueAt"] != "2026-11-01T06:30:00Z" {
		t.Fatal("DST distinct instants collapsed", a, b)
	}
	id := a["id"].(string)
	p.fail = true
	personalValue(t, personalHTTP(t, s, "customer", "POST", "/reminders/"+id+"/fire", "failed-claim", map[string]int{"version": 1}), 500)
	p.fail = false
	if s.state.Reminders[0].Status != "pending" || s.state.Reminders[0].Version != 1 {
		t.Fatal("failed persistence consumed reminder")
	}
	claimed := personalValue(t, personalHTTP(t, s, "customer", "POST", "/reminders/"+id+"/fire", "failed-claim", map[string]int{"version": 1}), 200)
	if claimed["claimed"] != true {
		t.Fatal("retry after failed save did not claim")
	}
	future := personalValue(t, personalHTTP(t, s, "customer", "POST", "/reminders/"+b["id"].(string)+"/fire", "", map[string]int{"version": 1}), 200)
	if future["claimed"] != false {
		t.Fatal("second DST instant fired too soon")
	}
	now = time.Date(2026, 3, 31, 23, 30, 0, 0, time.UTC)
	month := personalValue(t, personalHTTP(t, s, "customer", "GET", "/work-logs?timeZone=Asia%2FShanghai", "", nil), 200)
	if month["today"] != "2026-04-01" || month["month"] != "2026-04" {
		t.Fatal("local midnight/month boundary wrong", month)
	}
	for _, endpoint := range []string{"/bootstrap", "/export"} {
		value := personalValue(t, personalHTTP(t, s, "admin", "GET", endpoint, "", nil), 200)
		raw := string(mustJSON(t, value))
		if strings.Contains(raw, "夏令时第一次") || strings.Contains(raw, "reminders") || strings.Contains(raw, "workLogs") {
			t.Fatal("private aggregates leaked through business snapshot", endpoint)
		}
	}
}
