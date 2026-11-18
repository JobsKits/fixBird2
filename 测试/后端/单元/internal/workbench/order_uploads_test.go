package workbench

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func uploadTestService(t *testing.T) (*Service, *FilePersistence, string) {
	t.Helper()
	root := t.TempDir()
	key := filepath.Join(root, "key")
	p, err := NewFilePersistence(filepath.Join(root, "data"), key)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { p.Close() })
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	return s, p, key
}
func testRawUpload(t *testing.T, s *Service, key string) OrderUpload {
	t.Helper()
	data, _ := base64.StdEncoding.DecodeString(orderVideoFixture)
	token, _, err := s.login("admin", "1234", key)
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest("POST", "/api/v38/order-uploads", bytes.NewReader(data))
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Idempotency-Key", key)
	request.Header.Set("Content-Type", "video/mp4")
	request.Header.Set("X-File-Name", "device.mp4")
	response := httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(response, request)
	if response.Code != 201 {
		t.Fatalf("upload %d: %s", response.Code, response.Body.String())
	}
	var upload OrderUpload
	if err = json.Unmarshal(response.Body.Bytes(), &upload); err != nil {
		t.Fatal(err)
	}
	return upload
}
func TestOrderMediaFramesAuthenticationAndCancellation(t *testing.T) {
	store := &orderMediaStore{dir: t.TempDir(), key: bytes.Repeat([]byte{7}, 32)}
	data := bytes.Repeat([]byte("device-private-original"), 12000)
	id := randomID("upload_")
	size, sum, err := store.put(context.Background(), id, bytes.NewReader(data))
	if err != nil {
		t.Fatal(err)
	}
	file, _ := store.path(id)
	encrypted, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encrypted, []byte("device-private-original")) {
		t.Fatal("original leaked on disk")
	}
	reader, err := store.open(context.Background(), id, size, sum)
	if err != nil {
		t.Fatal(err)
	}
	got, err := io.ReadAll(reader)
	reader.Close()
	if err != nil || !bytes.Equal(got, data) {
		t.Fatal("framed roundtrip", err)
	}
	mutations := map[string][]byte{
		"missing_terminal": encrypted[:len(encrypted)-32],
		"trailing":         append(append([]byte{}, encrypted...), 1),
		"tampered":         append([]byte{}, encrypted...),
		"reordered":        append([]byte{}, encrypted...),
	}
	mutations["tampered"][40] ^= 1
	frame := 4 + 12 + orderMediaChunk + 16
	a := len(orderMediaFormat)
	b := a + frame
	copy(mutations["reordered"][a:b], encrypted[b:b+frame])
	copy(mutations["reordered"][b:b+frame], encrypted[a:b])
	for name, value := range mutations {
		t.Run(name, func(t *testing.T) {
			os.WriteFile(file, value, 0600)
			r, err := store.open(context.Background(), id, size, sum)
			if err == nil {
				_, err = io.Copy(io.Discard, r)
				r.Close()
			}
			if err == nil {
				t.Fatal("corrupt media accepted")
			}
		})
	}
	canceled, cancel := context.WithCancel(context.Background())
	cancel()
	if _, _, err = store.put(canceled, randomID("upload_"), bytes.NewReader(data)); !errors.Is(err, context.Canceled) {
		t.Fatal("cancellation ignored", err)
	}
	temporary, _ := filepath.Glob(filepath.Join(store.dir, ".upload-*"))
	if len(temporary) != 0 {
		t.Fatal("canceled upload left temporary file")
	}
}
func TestOrderUploadBindingRollbackRestartAndPortableBackup(t *testing.T) {
	s, p, key := uploadTestService(t)
	upload := testRawUpload(t, s, "portable")
	again := testRawUpload(t, s, "portable")
	if upload.ID != again.ID {
		t.Fatal("same key lost receipt")
	}
	actor := testActor(s, "admin")
	input := CreateOrderInput{Type: "mail", Customer: "设备客户", CustomerID: "customer", CompanyID: "company-a", Device: "设备", Description: "原件绑定", Files: []OrderMediaInput{{UploadID: upload.ID}, {UploadID: upload.ID}}}
	if _, err := mediaOrderWrite(s, actor, input, "duplicate-reference"); err == nil {
		t.Fatal("duplicate reference accepted")
	}
	if s.state.OrderUploads[upload.ID].OrderID != "" {
		t.Fatal("failed aggregate bound original")
	}
	input.Files = input.Files[:1]
	order, err := mediaOrderWrite(s, actor, input, "portable-order")
	if err != nil {
		t.Fatal(err)
	}
	if len(order.Evidence) != 1 || order.Evidence[0].Data != "" || order.Evidence[0].BlobID != "" || order.Evidence[0].Size != upload.Size {
		t.Fatal("invalid public projection")
	}
	restarted, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	original := testOrder(t, restarted, order.ID).Evidence[0]
	if original.BlobID != upload.ID {
		t.Fatal("restart lost reference")
	}
	backup := filepath.Join(t.TempDir(), "backup.enc")
	wrongKey := filepath.Join(t.TempDir(), "wrong-key")
	if err = os.WriteFile(wrongKey, bytes.Repeat([]byte{8}, 32), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = WriteBackup(p, wrongKey, backup); err == nil {
		t.Fatal("unrelated backup key accepted for encrypted sidecars")
	}
	manifest, err := WriteBackup(p, key, backup)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.Media) != 1 {
		t.Fatal("backup omitted sidecar")
	}
	target := filepath.Join(t.TempDir(), "restore")
	if err = RestoreBackup(backup, key, p.dir, target); err != nil {
		t.Fatal(err)
	}
	restored, err := NewFilePersistence(target, key)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	restoredService, err := New(restored)
	if err != nil {
		t.Fatal(err)
	}
	token, _, err := restoredService.login("customer", "Demo-Repair-2026!", "restored")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "/api/v38/orders/"+order.ID+"/evidence/"+original.ID, nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	restoredService.Handler(t.TempDir()).ServeHTTP(response, request)
	expected, _ := base64.StdEncoding.DecodeString(orderVideoFixture)
	if response.Code != 200 || !bytes.Equal(expected, response.Body.Bytes()) {
		t.Fatal("portable restored original not accessible", response.Code)
	}
	sidecar := filepath.Join(backup+".media", upload.ID+".enc")
	raw, _ := os.ReadFile(sidecar)
	raw[len(raw)/2] ^= 1
	os.WriteFile(sidecar, raw, 0600)
	badTarget := filepath.Join(t.TempDir(), "bad-restore")
	if err = RestoreBackup(backup, key, p.dir, badTarget); err == nil {
		t.Fatal("tampered backup original accepted")
	}
	if _, err = os.Stat(badTarget); !os.IsNotExist(err) {
		t.Fatal("failed restore exposed partial target")
	}
}

func TestOrderUploadFailedPersistenceAndAuthorization(t *testing.T) {
	s, p := testService(t)
	s.orderMedia = &orderMediaStore{dir: t.TempDir(), key: bytes.Repeat([]byte{5}, 32)}
	token, _, err := s.login("admin", "1234", "failed-upload")
	if err != nil {
		t.Fatal(err)
	}
	data, _ := base64.StdEncoding.DecodeString(orderVideoFixture)
	request := func() *httptest.ResponseRecorder {
		r := httptest.NewRequest("POST", "/api/v38/order-uploads", bytes.NewReader(data))
		r.Header.Set("Authorization", "Bearer "+token)
		r.Header.Set("Idempotency-Key", "failed-upload")
		r.Header.Set("Content-Type", "video/mp4")
		r.Header.Set("X-File-Name", "device.mp4")
		w := httptest.NewRecorder()
		s.Handler(t.TempDir()).ServeHTTP(w, r)
		return w
	}
	p.fail = true
	if w := request(); w.Code != 500 {
		t.Fatalf("failed persistence: %d %s", w.Code, w.Body.String())
	}
	files, _ := os.ReadDir(s.orderMedia.dir)
	if len(files) != 0 || len(s.state.OrderUploads) != 0 {
		t.Fatal("failed save leaked staged original or receipt")
	}
	p.fail = false
	w := request()
	if w.Code != 201 {
		t.Fatalf("same intent could not retry: %d %s", w.Code, w.Body.String())
	}
	var upload OrderUpload
	json.Unmarshal(w.Body.Bytes(), &upload)
	input := CreateOrderInput{Type: "mail", Customer: "设备客户", CustomerID: "customer", CompanyID: "company-a", Device: "设备", Description: "权限与落盘", Files: []OrderMediaInput{{UploadID: upload.ID}}}
	if _, err = mediaOrderWrite(s, testActor(s, "customer-b"), input, "foreign-upload"); err == nil {
		t.Fatal("cross actor binding accepted")
	}
	p.fail = true
	if _, err = mediaOrderWrite(s, testActor(s, "admin"), input, "failed-order-save"); err == nil {
		t.Fatal("failed order save accepted")
	}
	if s.state.OrderUploads[upload.ID].OrderID != "" {
		t.Fatal("failed order save consumed upload")
	}
	p.fail = false
	oldActor := testActor(s, "admin")
	for i := range s.state.Accounts {
		if s.state.Accounts[i].Actor.ID == oldActor.ID {
			s.state.Accounts[i].Actor.AuthVersion++
		}
	}
	if _, err = s.bindOrderUpload(&s.state, testActor(s, "admin"), "order", input.Files[0], s.now()); err == nil {
		t.Fatal("revoked upload capability accepted")
	}
}

func TestOrderOriginalDeletionCommitsBeforeCleanupAndCannotRestore(t *testing.T) {
	s, p, key := uploadTestService(t)
	upload := testRawUpload(t, s, "delete-original")
	input := CreateOrderInput{Type: "mail", Customer: "删除客户", CustomerID: "customer", CompanyID: "company-a", Device: "设备", Description: "删除原件", Files: []OrderMediaInput{{UploadID: upload.ID}}}
	actor := testActor(s, "admin")
	order, err := mediaOrderWrite(s, actor, input, "delete-order")
	if err != nil {
		t.Fatal(err)
	}
	blob, _ := s.orderMedia.path(upload.ID)
	backup := filepath.Join(t.TempDir(), "before-delete.enc")
	if _, err = WriteBackup(p, key, backup); err != nil {
		t.Fatal(err)
	}
	payload, _ := json.Marshal(map[string]any{"evidenceId": order.Evidence[0].ID, "reason": "客户要求删除合成原件"})
	action := Action{Type: "delete_evidence", Version: order.Version, Payload: payload}
	raw, _ := json.Marshal(action)
	remove := func() error {
		_, _, err := s.transact(actor, "POST /api/v38/orders/"+order.ID+"/actions", "delete-original-action", raw, 200, func(state *State) (any, error) { return s.act(state, actor, order.ID, action) })
		return err
	}
	persisted, _ := p.Load()
	s.persistence = &testPersistence{data: persisted, fail: true}
	if err = remove(); err == nil {
		t.Fatal("failed deletion save accepted")
	}
	if _, err = os.Stat(blob); err != nil {
		t.Fatal("original deleted before transaction commit", err)
	}
	if testOrder(t, s, order.ID).Evidence[0].Deleted {
		t.Fatal("failed transaction changed evidence")
	}
	s.persistence = p
	if err = remove(); err != nil {
		t.Fatal(err)
	}
	if _, err = os.Stat(blob); !os.IsNotExist(err) {
		t.Fatal("committed deletion retained original", err)
	}
	deleted := testOrder(t, s, order.ID).Evidence[0]
	if !deleted.Deleted || deleted.BlobID != "" {
		t.Fatal("deleted evidence retained storage capability")
	}
	after := filepath.Join(t.TempDir(), "after-delete.enc")
	manifest, err := WriteBackup(p, key, after)
	if err != nil || len(manifest.Media) != 0 {
		t.Fatal("bound upload tombstone required a missing blob", err)
	}
	target := filepath.Join(t.TempDir(), "restored")
	if err = RestoreBackup(backup, key, p.dir, target); err != nil {
		t.Fatal(err)
	}
	restored, err := NewFilePersistence(target, key)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	restoredService, err := New(restored)
	if err != nil {
		t.Fatal(err)
	}
	token, _, _ := restoredService.login("customer", "Demo-Repair-2026!", "deleted-restored")
	request := httptest.NewRequest("GET", "/api/v38/orders/"+order.ID+"/evidence/"+order.Evidence[0].ID, nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	restoredService.Handler(t.TempDir()).ServeHTTP(response, request)
	if response.Code != 404 {
		t.Fatal("backup revived deleted original", response.Code)
	}
	orphan := randomID("upload_")
	if _, _, err = s.orderMedia.put(context.Background(), orphan, bytes.NewReader([]byte("uncommitted"))); err != nil {
		t.Fatal(err)
	}
	temporary := filepath.Join(s.orderMedia.dir, ".upload-interrupted")
	os.WriteFile(temporary, []byte("interrupted"), 0600)
	if _, err = New(p); err != nil {
		t.Fatal(err)
	}
	orphanPath, _ := s.orderMedia.path(orphan)
	for _, path := range []string{orphanPath, temporary} {
		if _, err = os.Stat(path); !os.IsNotExist(err) {
			t.Fatal("restart retained abandoned original", path)
		}
	}
}
