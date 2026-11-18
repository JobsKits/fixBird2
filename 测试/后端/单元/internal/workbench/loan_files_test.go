package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"net/http/httptest"
	"strings"
	"testing"
)

func loanImageFixture(t *testing.T, width int) PurchaseAttachmentInput {
	t.Helper()
	var data bytes.Buffer
	if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, width, 16))); err != nil {
		t.Fatal(err)
	}
	return PurchaseAttachmentInput{Name: "合成借还凭据.png", MIME: "image/png", DataBase64: base64.StdEncoding.EncodeToString(data.Bytes())}
}

func loanHTTPFixture(t *testing.T, s *Service, method, endpoint, actor, key string, input any) *httptest.ResponseRecorder {
	t.Helper()
	raw, err := json.Marshal(input)
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest(method, "/api/v38"+endpoint, bytes.NewReader(raw))
	if actor != "" {
		token, _, err := s.login(actor, "Demo-Repair-2026!", "loan-http-fixture")
		if err != nil {
			t.Fatal(err)
		}
		r.Header.Set("Authorization", "Bearer "+token)
	}
	if key != "" {
		r.Header.Set("Idempotency-Key", key)
	}
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}

func decodedLoan(t *testing.T, response *httptest.ResponseRecorder, status int) Loan {
	t.Helper()
	if response.Code != status {
		t.Fatalf("loan HTTP status=%d want=%d body=%s", response.Code, status, response.Body.String())
	}
	var loan Loan
	if err := json.Unmarshal(response.Body.Bytes(), &loan); err != nil {
		t.Fatal(err)
	}
	for _, file := range loan.Files {
		if file.DataBase64 != "" {
			t.Fatal("private loan bytes escaped in JSON response")
		}
	}
	return loan
}

func TestLoanFilesAtomicWorkflowAndAuthorization(t *testing.T) {
	s, persistence := testService(t)
	part, _ := findPart(&s.state, "part-board")
	before := part.Available
	input := LoanInput{OrderID: "wo_intake", PartID: "part-board", Quantity: 2, BorrowerID: "engineer", DueAt: "2027-01-01T23:59:59+08:00", Note: "合成借出交接事实", Attachments: []PurchaseAttachmentInput{loanImageFixture(t, 24)}}
	created := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "loan-proof-create", input), 201)
	if len(created.Files) != 1 || created.Files[0].Stage != "borrow" || created.Files[0].Quantity != 2 || created.Files[0].UploaderID != "warehouse" {
		t.Fatal("borrow proof context missing")
	}
	part, _ = findPart(&s.state, "part-board")
	if part.Available != before-2 {
		t.Fatal("borrow stock movement incorrect")
	}
	replayed := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "loan-proof-create", input), 201)
	if replayed.ID != created.ID || len(replayed.Files) != 1 {
		t.Fatal("replay duplicated borrow proof")
	}
	part, _ = findPart(&s.state, "part-board")
	if part.Available != before-2 {
		t.Fatal("idempotent borrow moved stock twice")
	}
	filePath := "/loans/" + created.ID + "/files/" + created.Files[0].ID
	for _, actor := range []string{"warehouse", "admin", "dispatcher", "engineer"} {
		response := loanHTTPFixture(t, s, "GET", filePath, actor, "", nil)
		if response.Code != 200 || response.Header().Get("Content-Type") != "image/png" || !bytes.HasPrefix(response.Body.Bytes(), []byte("\x89PNG")) {
			t.Fatalf("authorized original failed: %s %d", actor, response.Code)
		}
	}
	for _, actor := range []string{"customer", "customer-b", "outsource", "finance", ""} {
		response := loanHTTPFixture(t, s, "GET", filePath, actor, "", nil)
		if response.Code != 401 && response.Code != 404 {
			t.Fatalf("private original leaked to %q: %d", actor, response.Code)
		}
	}
	bootstrap := loanHTTPFixture(t, s, "GET", "/bootstrap", "warehouse", "", nil)
	if strings.Contains(bootstrap.Body.String(), `"dataBase64"`) || !strings.Contains(bootstrap.Body.String(), created.Files[0].ID) {
		t.Fatal("bootstrap loan projection unsafe or missing metadata")
	}
	bad := loanImageFixture(t, 24)
	bad.MIME = "image/jpeg"
	badAction := Action{Type: "return", Version: 1, Payload: json.RawMessage(loanJSONFixture(t, map[string]any{"quantity": 1, "condition": "good", "attachments": []PurchaseAttachmentInput{bad}}))}
	response := loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/actions", "warehouse", "invalid-return-proof", badAction)
	if response.Code != 422 {
		t.Fatalf("fake image accepted: %d", response.Code)
	}
	part, _ = findPart(&s.state, "part-board")
	if part.Available != before-2 {
		t.Fatal("failed proof returned stock")
	}
	returnBody := map[string]any{"quantity": 1, "condition": "good", "note": "合成归还现场事实", "attachments": []PurchaseAttachmentInput{loanImageFixture(t, 30)}}
	returnAction := Action{Type: "return", Version: 1, Payload: json.RawMessage(loanJSONFixture(t, returnBody))}
	returned := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/actions", "warehouse", "return-proof-one", returnAction), 200)
	if returned.Outstanding != 1 || returned.Version != 2 || len(returned.Files) != 2 || returned.Files[1].Stage != "return" || returned.Files[1].Note != returnBody["note"] {
		t.Fatal("return and proof were not committed together")
	}
	returnAction.Version = 2
	persistence.fail = true
	response = loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/actions", "warehouse", "return-proof-two", returnAction)
	if response.Code != 500 {
		t.Fatal("failed return save accepted")
	}
	part, _ = findPart(&s.state, "part-board")
	if part.Available != before-1 {
		t.Fatal("failed save partially changed stock")
	}
	persistence.fail = false
	returned = decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/actions", "warehouse", "return-proof-two", returnAction), 200)
	if returned.Outstanding != 0 || len(returned.Files) != 3 {
		t.Fatal("failed save could not retry with original proof intent")
	}
	backfill := map[string]any{"version": returned.Version, "stage": "borrow", "quantity": 2, "note": "补录实际凭据", "attachments": []PurchaseAttachmentInput{loanImageFixture(t, 40)}}
	filled := decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/files", "warehouse", "loan-backfill", backfill), 200)
	if filled.Version != returned.Version+1 || len(filled.Files) != 4 {
		t.Fatal("backfill did not version the proof record")
	}
	part, _ = findPart(&s.state, "part-board")
	if part.Available != before {
		t.Fatal("backfill changed inventory")
	}
	if response = loanHTTPFixture(t, s, "POST", "/loans/"+created.ID+"/files", "warehouse", "loan-backfill-stale", backfill); response.Code != 409 {
		t.Fatal("backfill accepted stale version")
	}
	stored, err := New(persistence)
	if err != nil {
		t.Fatal(err)
	}
	if response = loanHTTPFixture(t, stored, "GET", filePath, "engineer", "", nil); response.Code != 200 {
		t.Fatal("proof original was not retained across restart")
	}
}

func loanJSONFixture(t *testing.T, value any) []byte {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestLoanFilesLegacyAndLimits(t *testing.T) {
	s, _ := testService(t)
	input := LoanInput{PartID: "part-board", Quantity: 1, BorrowerID: "engineer", DueAt: "2027-01-01T23:59:59+08:00", Note: "旧客户端合成借出"}
	decodedLoan(t, loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "legacy-loan", input), 201)
	// A present empty array is a failed proof submission; omission remains legacy compatible.
	raw := map[string]any{"partId": input.PartID, "quantity": 1, "borrowerId": "engineer", "dueAt": input.DueAt, "note": input.Note, "attachments": []any{}}
	if response := loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "empty-proof", raw); response.Code != 422 {
		t.Fatal("explicit empty proof was accepted")
	}
	for _, tc := range []struct {
		name  string
		input PurchaseAttachmentInput
	}{
		{"oversized-dimensions", loanImageFixture(t, 8193)},
		{"unsupported-document", PurchaseAttachmentInput{Name: "not-image.txt", MIME: "text/plain", DataBase64: base64.StdEncoding.EncodeToString([]byte("synthetic text"))}},
		{"path-name", PurchaseAttachmentInput{Name: "../proof.png", MIME: "image/png", DataBase64: loanImageFixture(t, 20).DataBase64}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			input.Attachments = []PurchaseAttachmentInput{tc.input}
			if response := loanHTTPFixture(t, s, "POST", "/loans", "warehouse", randomID("bad_"), input); response.Code != 422 {
				t.Fatalf("invalid proof accepted: %d", response.Code)
			}
		})
	}
	input.Attachments = make([]PurchaseAttachmentInput, 9)
	for i := range input.Attachments {
		input.Attachments[i] = loanImageFixture(t, 20)
	}
	if response := loanHTTPFixture(t, s, "POST", "/loans", "warehouse", "too-many-proof", input); response.Code != 413 {
		t.Fatal("image count limit not enforced")
	}
	imageData, _ := base64.StdEncoding.DecodeString(loanImageFixture(t, 20).DataBase64)
	imageData = append(imageData, make([]byte, purchaseFileMaxBytes-len(imageData))...)
	encoded := base64.StdEncoding.EncodeToString(imageData)
	files := []LoanFile{}
	for i := 0; i < 5; i++ {
		files = append(files, LoanFile{PurchaseFile: PurchaseFile{ID: fmt.Sprintf("loan_file_%d", i), Name: "proof.png", MIME: "image/png", Size: len(imageData), DataBase64: encoded}, Stage: "borrow", Quantity: 1})
	}
	if err := validateLoanFiles(files, 1); err == nil {
		t.Fatal("aggregate 32MiB limit not enforced")
	}
}
