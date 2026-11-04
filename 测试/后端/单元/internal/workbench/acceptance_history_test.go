package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

func acceptanceTestSignature(t *testing.T, shade uint8) string {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 80, 40))
	for x := 5; x < 65; x++ {
		img.Set(x, 5+x%25, color.RGBA{R: shade, G: 40, B: 60, A: 255})
	}
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, img); err != nil {
		t.Fatal(err)
	}
	return "data:image/png;base64," + base64.StdEncoding.EncodeToString(encoded.Bytes())
}

func acceptanceActionBody(t *testing.T, version int, passed bool, signature, note string) []byte {
	t.Helper()
	payload, err := json.Marshal(map[string]any{"passed": passed, "signature": signature, "note": note})
	if err != nil {
		t.Fatal(err)
	}
	body, err := json.Marshal(Action{Type: "accept", Version: version, Payload: payload})
	if err != nil {
		t.Fatal(err)
	}
	return body
}

func acceptanceResponse(t *testing.T, raw []byte) Order {
	t.Helper()
	var order Order
	if err := json.Unmarshal(raw, &order); err != nil {
		t.Fatal(err)
	}
	return order
}

func TestAcceptanceHistoryHTTPReplayRestartAndRestore(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "live")
	keyFile := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	s, err := New(p)
	if err != nil {
		t.Fatal(err)
	}
	clock := r4Time(t, "2026-10-15T10:00:00+08:00")
	delivery := r4Delivery(t, s, clock, 3, true)
	token := secondPermissionToken(t, s, "customer")
	firstSignature := acceptanceTestSignature(t, 20)
	firstBody := acceptanceActionBody(t, delivery.Version, false, firstSignature, "合成第一次验收不通过：仍有故障")
	path := "/api/v38/orders/" + delivery.ID + "/actions"
	w := secondPermissionHTTP(s, token, http.MethodPost, path, "acceptance-first", firstBody)
	if w.Code != http.StatusOK {
		t.Fatalf("first rejection: %d %s", w.Code, w.Body.String())
	}
	first := acceptanceResponse(t, w.Body.Bytes())
	if len(first.AcceptanceRecords) != 1 {
		t.Fatal("missing rejected signature record")
	}
	record := first.AcceptanceRecords[0]
	if record.ID == "" || record.Passed || record.Signature != firstSignature || record.SignerID != "customer" || record.SignerName != testActor(s, "customer").Name || record.SignedAt != nowString(clock) || record.QuoteVersion != 2 || record.OrderVersion != first.Version || record.Note == "" || record.IssueID != first.Issues[0].ID {
		t.Fatal("incomplete signed rejection record", record)
	}
	if first.Outcome != "" || first.AcceptedAt != "" || first.AcceptanceSignature != "" || first.Warranty != (Warranty{}) || first.Status != "pending_acceptance" {
		t.Fatal("rejection fabricated acceptance", first)
	}

	t.Run("idempotent_retry_keeps_one_original", func(t *testing.T) {
		w := secondPermissionHTTP(s, token, http.MethodPost, path, "acceptance-first", firstBody)
		retry := acceptanceResponse(t, w.Body.Bytes())
		if w.Code != http.StatusOK || retry.Version != first.Version || len(retry.AcceptanceRecords) != 1 || !reflect.DeepEqual(retry.AcceptanceRecords[0], record) || len(retry.Issues) != 1 {
			t.Fatalf("retry changed signed record: %d %+v", w.Code, retry)
		}
	})

	t.Run("failed_acceptance_does_not_append", func(t *testing.T) {
		before, _ := p.Load()
		for _, body := range [][]byte{
			acceptanceActionBody(t, first.Version, true, acceptanceTestSignature(t, 21), "仍有异议不可通过"),
			acceptanceActionBody(t, first.Version, false, "invalid", "无效签名"),
			acceptanceActionBody(t, first.Version, false, firstSignature, ""),
		} {
			w := secondPermissionHTTP(s, token, http.MethodPost, path, randomID("invalid_"), body)
			if w.Code != http.StatusUnprocessableEntity {
				t.Fatalf("invalid acceptance status=%d body=%s", w.Code, w.Body.String())
			}
		}
		after, _ := p.Load()
		if !bytes.Equal(before, after) || len(testOrder(t, s, delivery.ID).AcceptanceRecords) != 1 {
			t.Fatal("rejected transaction changed original")
		}
	})

	// Restart before resolution must retain the non-passing original and its block.
	if err := p.Close(); err != nil {
		t.Fatal(err)
	}
	p, err = NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	s, err = New(p)
	if err != nil {
		t.Fatal(err)
	}
	s.now = func() time.Time { return clock.AddDate(0, 0, 10) }
	if err = s.SweepAutoAcceptance(); err != nil {
		t.Fatal(err)
	}
	restarted := testOrder(t, s, delivery.ID)
	if restarted.AcceptedAt != "" || !reflect.DeepEqual(restarted.AcceptanceRecords[0], record) || len(restarted.Issues) != 1 || !restarted.RestartReview {
		t.Fatal("restart lost rejection or auto-accepted")
	}
	t.Run("retry_after_restart_uses_current_authorized_history", func(t *testing.T) {
		token := secondPermissionToken(t, s, "customer")
		w := secondPermissionHTTP(s, token, http.MethodPost, path, "acceptance-first", firstBody)
		retried := acceptanceResponse(t, w.Body.Bytes())
		if w.Code != http.StatusOK || len(retried.AcceptanceRecords) != 1 || !reflect.DeepEqual(retried.AcceptanceRecords[0], record) || !retried.RestartReview {
			t.Fatal("restart retry changed historical signature", w.Code)
		}
	})

	s.now = func() time.Time { return clock.Add(time.Hour) }
	secondSignature := acceptanceTestSignature(t, 35)
	second := mustAct(t, s, "customer", delivery.ID, "accept", map[string]any{"passed": false, "signature": secondSignature, "note": "合成第二次验收不通过：问题尚存"})
	if len(second.AcceptanceRecords) != 2 || !reflect.DeepEqual(second.AcceptanceRecords[0], record) || second.AcceptanceRecords[1].ID == record.ID || second.AcceptanceRecords[1].Signature != secondSignature {
		t.Fatal("second rejection overwrote original")
	}
	for _, issue := range second.Issues {
		mustAct(t, s, "dispatcher", second.ID, "resolve_issue", map[string]any{"issueId": issue.ID, "note": "合成整改经客户核对，独立处理每项异议"})
	}
	acceptedSignature := acceptanceTestSignature(t, 50)
	accepted := mustAct(t, s, "customer", delivery.ID, "accept", map[string]any{"passed": true, "signature": acceptedSignature, "note": "合成整改后通过"})
	if len(accepted.AcceptanceRecords) != 3 || !reflect.DeepEqual(accepted.AcceptanceRecords[0], record) || !accepted.AcceptanceRecords[2].Passed || accepted.AcceptanceSignature != acceptedSignature {
		t.Fatal("later acceptance overwrote historical rejection")
	}
	fullHistory := append([]AcceptanceRecord{}, accepted.AcceptanceRecords...)
	backup := filepath.Join(dir, "backups", "history.wbbak")
	if _, err = WriteBackup(p, keyFile, backup); err != nil {
		t.Fatal(err)
	}
	encrypted, err := os.ReadFile(backup)
	if err != nil || bytes.Contains(encrypted, []byte(firstSignature)) {
		t.Fatal("signed original exposed in encrypted backup", err)
	}
	mustAct(t, s, "dispatcher", delivery.ID, "handover_contact", map[string]any{"customerId": "customer-peer", "reason": "合成当前经办授权交接"})
	target := filepath.Join(dir, "restored")
	if err = RestoreBackup(backup, keyFile, dataDir, target); err != nil {
		t.Fatal(err)
	}
	rp, err := NewFilePersistence(target, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer rp.Close()
	restored, err := New(rp)
	if err != nil {
		t.Fatal(err)
	}
	restored.now = func() time.Time { return clock.Add(2 * time.Hour) }
	o := testOrder(t, restored, delivery.ID)
	if o.CustomerID != "customer-peer" || !reflect.DeepEqual(o.AcceptanceRecords, fullHistory) || o.AcceptanceRecords[0].SignerID != "customer" {
		t.Fatal("recovery changed signed history or revived old authorization")
	}

	for _, actorID := range []string{"admin", "dispatcher", "finance", "customer-peer", "customer", "customer-b", "engineer", "warehouse", "qc", "outsource"} {
		t.Run("read_"+actorID, func(t *testing.T) {
			token := secondPermissionToken(t, restored, actorID)
			allowed := actorID == "admin" || actorID == "dispatcher" || actorID == "finance" || actorID == "customer-peer"
			for _, endpoint := range []string{"/api/v38/orders/" + delivery.ID, "/api/v38/export"} {
				w := secondPermissionHTTP(restored, token, http.MethodGet, endpoint, "", nil)
				var orders []Order
				if endpoint == "/api/v38/export" && w.Code == http.StatusOK {
					var value struct {
						Orders []Order `json:"orders"`
					}
					if err := json.Unmarshal(w.Body.Bytes(), &value); err != nil {
						t.Fatal(err)
					}
					orders = value.Orders
				} else if w.Code == http.StatusOK {
					orders = []Order{acceptanceResponse(t, w.Body.Bytes())}
				}
				found := false
				for _, order := range orders {
					if order.ID != delivery.ID {
						continue
					}
					found = true
					if allowed && !reflect.DeepEqual(order.AcceptanceRecords, fullHistory) || !allowed && len(order.AcceptanceRecords) != 0 {
						t.Fatalf("%s signed record grant mismatch", endpoint)
					}
				}
				if allowed && (w.Code != http.StatusOK || !found) || bytes.Contains(w.Body.Bytes(), []byte(firstSignature)) != allowed {
					t.Fatalf("%s status=%d original visibility mismatch for %s", endpoint, w.Code, actorID)
				}
			}
			for _, endpoint := range []string{"/api/v38/orders", "/api/v38/bootstrap"} {
				w := secondPermissionHTTP(restored, token, http.MethodGet, endpoint, "", nil)
				if w.Code != http.StatusOK || bytes.Contains(w.Body.Bytes(), []byte(firstSignature)) || bytes.Contains(w.Body.Bytes(), []byte("acceptanceRecords")) {
					t.Fatalf("summary contains signed originals: %s status=%d", endpoint, w.Code)
				}
			}
			if actorID == "customer" {
				w := secondPermissionHTTP(restored, token, http.MethodPost, path, "acceptance-first", firstBody)
				if w.Code != http.StatusNotFound || bytes.Contains(w.Body.Bytes(), []byte(firstSignature)) {
					t.Fatal("revoked original signer retrieved cached acceptance")
				}
			}
		})
	}
}

func TestAcceptanceSignatureSaveFailureIsAtomic(t *testing.T) {
	s, p := testService(t)
	o := r4Delivery(t, s, r4Time(t, "2026-10-15T10:00:00+08:00"), 3, false)
	before := append([]byte{}, p.data...)
	payload := map[string]any{"passed": false, "signature": acceptanceTestSignature(t, 60), "note": "合成拒绝需原子保存"}
	key := "acceptance-storage-retry"
	p.fail = true
	_, err := testActVersion(s, testActor(s, "customer"), o.ID, "accept", payload, o.Version, key)
	if err == nil || !bytes.Equal(before, p.data) || len(testOrder(t, s, o.ID).AcceptanceRecords) != 0 || len(testOrder(t, s, o.ID).Issues) != 0 {
		t.Fatal("failed save left partial signature/issue")
	}
	p.fail = false
	retried, err := testActVersion(s, testActor(s, "customer"), o.ID, "accept", payload, o.Version, key)
	if err != nil || len(retried.AcceptanceRecords) != 1 || len(retried.Issues) != 1 {
		t.Fatal("failed storage consumed idempotency key", err)
	}
}
