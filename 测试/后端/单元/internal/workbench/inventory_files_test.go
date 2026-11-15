package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func inventoryPurchaseBody(t *testing.T, attachments ...map[string]any) map[string]any {
	t.Helper()
	return map[string]any{"supplier": "supplier", "partId": "part-board", "quantity": 3, "unitCents": 1000, "note": "采购附件合成依据", "attachments": attachments}
}
func inventoryPNG(t *testing.T) map[string]any {
	return map[string]any{"name": "采购图片.png", "mime": "image/png", "dataBase64": testJournalPNG(t)}
}
func inventoryDownload(s *Service, who, path string) *httptest.ResponseRecorder {
	token := "inventory-download-" + who
	s.mu.Lock()
	s.sessions[token] = session{Actor: testActor(s, who), ExpiresAt: s.now().Add(12 * 60 * 60 * 1000000000)}
	s.mu.Unlock()
	r := httptest.NewRequest("GET", "/api/v38"+path, nil)
	r.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}
func TestInventoryDetailsKeepOriginalRoleFilters(t *testing.T) {
	s, _ := testService(t)
	created := personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "", inventoryPurchaseBody(t)), 201)
	id := created["id"].(string)
	for _, who := range []string{"customer", "supplier", "outsource"} {
		personalValue(t, personalHTTP(t, s, who, "GET", "/parts/part-board", "", nil), 403)
	}
	engineer := personalValue(t, personalHTTP(t, s, "engineer", "GET", "/parts/part-board", "", nil), 200)
	if len(engineer["purchases"].([]any)) != 0 {
		t.Fatal("engineer read unauthorized purchases")
	}
	for _, v := range engineer["loans"].([]any) {
		if v.(map[string]any)["borrowerId"] != "engineer" {
			t.Fatal("another borrower leaked")
		}
	}
	qc := personalValue(t, personalHTTP(t, s, "qc", "GET", "/parts/part-board", "", nil), 200)
	if len(qc["purchases"].([]any)) != 0 || len(qc["loans"].([]any)) != 0 {
		t.Fatal("QC got financial or borrower records")
	}
	personalValue(t, personalHTTP(t, s, "supplier", "GET", "/purchases/"+id, "", nil), 200)
	for _, who := range []string{"engineer", "customer", "customer-b"} {
		personalValue(t, personalHTTP(t, s, who, "GET", "/purchases/"+id, "", nil), 404)
	}
	personalValue(t, personalHTTP(t, s, "", "GET", "/parts/part-board", "", nil), 401)
}
func TestPurchasePrivateFilesProjectionVersionAndDownload(t *testing.T) {
	s, p := testService(t)
	image := inventoryPNG(t)
	raw := inventoryPurchaseBody(t, image)
	created := personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "purchase-files-create", raw), 201)
	id := created["id"].(string)
	fileID := created["files"].([]any)[0].(map[string]any)["id"].(string)
	if strings.Contains(string(mustJSON(t, created)), "dataBase64") {
		t.Fatal("create leaked payload")
	}
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "purchase-files-create", raw), 201)
	if len(s.state.Purchases[len(s.state.Purchases)-1].Files) != 1 {
		t.Fatal("create replay duplicated files")
	}
	for _, route := range []string{"/bootstrap", "/export", "/purchases/" + id, "/parts/part-board"} {
		out := personalValue(t, personalHTTP(t, s, "admin", "GET", route, "", nil), 200)
		if strings.Contains(string(mustJSON(t, out)), image["dataBase64"].(string)) {
			t.Fatal("private payload in projection", route)
		}
	}
	url := "/purchases/" + id + "/attachments/" + fileID
	for _, who := range []string{"admin", "warehouse", "finance", "dispatcher", "supplier"} {
		w := inventoryDownload(s, who, url)
		if w.Code != 200 || w.Header().Get("Content-Type") != "image/png" || !strings.HasPrefix(w.Header().Get("Content-Disposition"), "attachment; filename*=UTF-8''") {
			t.Fatal(w.Code, w.Header())
		}
		raw, _ := base64.StdEncoding.DecodeString(image["dataBase64"].(string))
		if !bytes.Equal(w.Body.Bytes(), raw) {
			t.Fatal("download changed original")
		}
	}
	for _, who := range []string{"engineer", "customer", "qc"} {
		if w := inventoryDownload(s, who, url); w.Code != 404 {
			t.Fatal(who, w.Code)
		}
	}
	attach := map[string]any{"version": 1, "name": "采购依据.txt", "mime": "text/plain", "dataBase64": base64.StdEncoding.EncodeToString([]byte("private purchase document"))}
	for _, who := range []string{"finance", "supplier"} {
		personalValue(t, personalHTTP(t, s, who, "POST", "/purchases/"+id+"/attachments", "", attach), 403)
	}
	p.fail = true
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases/"+id+"/attachments", "upload-once", attach), 500)
	p.fail = false
	updated := personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases/"+id+"/attachments", "upload-once", attach), 200)
	if updated["version"] != float64(2) || len(updated["files"].([]any)) != 2 {
		t.Fatal(updated)
	}
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases/"+id+"/attachments", "upload-once", attach), 200)
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases/"+id+"/attachments", "", attach), 409)
	received := personalValue(t, personalHTTP(t, s, "warehouse", "POST", "/purchases/"+id+"/receive", "", map[string]any{"version": 2, "quantity": 1, "note": "实收依据"}), 200)
	if strings.Contains(string(mustJSON(t, received)), "dataBase64") {
		t.Fatal("receive leaked original")
	}
}
func TestPurchaseFilesRejectExecutablePathsAndSurviveRestart(t *testing.T) {
	s, p := testService(t)
	for _, file := range []map[string]any{
		{"name": "../secret.txt", "mime": "text/plain", "dataBase64": base64.StdEncoding.EncodeToString([]byte("plain"))},
		{"name": "evil\"\n.txt", "mime": "text/plain", "dataBase64": base64.StdEncoding.EncodeToString([]byte("plain"))},
		{"name": "evil.svg", "mime": "image/svg+xml", "dataBase64": base64.StdEncoding.EncodeToString([]byte("<svg onload='evil()'/>"))},
		{"name": "fake.txt", "mime": "text/plain", "dataBase64": base64.StdEncoding.EncodeToString([]byte("<script>evil()</script>"))},
		{"name": "fake.docx", "mime": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "dataBase64": base64.StdEncoding.EncodeToString([]byte("not a ZIP document"))},
	} {
		personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "", inventoryPurchaseBody(t, file)), 422)
	}
	many := []map[string]any{}
	for i := 0; i < 9; i++ {
		many = append(many, inventoryPNG(t))
	}
	personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "", inventoryPurchaseBody(t, many...)), 413)
	created := personalValue(t, personalHTTP(t, s, "admin", "POST", "/purchases", "", inventoryPurchaseBody(t, inventoryPNG(t))), 201)
	id := created["id"].(string)
	fileID := created["files"].([]any)[0].(map[string]any)["id"].(string)
	dir := t.TempDir()
	key := filepath.Join(dir, "keys", "storage.key")
	disk, err := NewFilePersistence(filepath.Join(dir, "data"), key)
	if err != nil {
		t.Fatal(err)
	}
	var persisted State
	if err := json.Unmarshal(p.data, &persisted); err != nil {
		t.Fatal(err)
	}
	if err := disk.Save(mustJSON(t, persisted)); err != nil {
		t.Fatal(err)
	}
	if err := disk.Close(); err != nil {
		t.Fatal(err)
	}
	disk, err = NewFilePersistence(filepath.Join(dir, "data"), key)
	if err != nil {
		t.Fatal(err)
	}
	defer disk.Close()
	restored, err := New(disk)
	if err != nil {
		t.Fatal(err)
	}
	if w := inventoryDownload(restored, "supplier", "/purchases/"+id+"/attachments/"+fileID); w.Code != 200 {
		t.Fatal(w.Code)
	}
	other := personalValue(t, personalHTTP(t, restored, "admin", "POST", "/purchases", "", inventoryPurchaseBody(t)), 201)["id"].(string)
	if w := inventoryDownload(restored, "admin", "/purchases/"+other+"/attachments/"+fileID); w.Code != 404 {
		t.Fatal("attachment escaped purchase ownership", w.Code)
	}
}
