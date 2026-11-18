package workbench

import (
	"archive/zip"
	"bytes"
	"encoding/base64"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"unicode"
)

const purchaseFileMaxBytes = 8 * 1024 * 1024

type PurchaseFile struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	MIME       string `json:"mime"`
	Size       int    `json:"size"`
	UploaderID string `json:"uploaderId"`
	CreatedAt  string `json:"createdAt"`
	DataBase64 string `json:"dataBase64,omitempty"`
}
type PurchaseAttachmentInput struct {
	Name       string `json:"name"`
	MIME       string `json:"mime"`
	DataBase64 string `json:"dataBase64"`
}

// Public purchase projections never include private file bytes.
func purchaseView(purchase Purchase) Purchase {
	purchase.Files = append([]PurchaseFile(nil), purchase.Files...)
	for i := range purchase.Files {
		purchase.Files[i].DataBase64 = ""
	}
	return purchase
}
func canReadPurchase(purchase Purchase, actor Actor) bool {
	return actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "finance" || actor.Role == "dispatcher" || actor.Role == "supplier" && (purchase.Supplier == actor.ID || purchase.Supplier == actor.Name)
}
func findPurchase(state *State, actor Actor, id string) (*Purchase, error) {
	for i := range state.Purchases {
		if state.Purchases[i].ID == id && canReadPurchase(state.Purchases[i], actor) {
			return &state.Purchases[i], nil
		}
	}
	return nil, fail(404, "not_found", "采购单不存在或无访问权限")
}
func validPurchaseFile(name, mime string, data []byte) error {
	if !validPersonalText(name, 1, 180) || strings.ContainsAny(name, "/\\\"") || strings.IndexFunc(name, unicode.IsControl) >= 0 {
		return fail(422, "invalid_file_name", "文件名不能含路径、引号或控制字符，最多180字符")
	}
	valid := false
	switch mime {
	case "image/png", "image/jpeg", "image/gif":
		valid = validateMIME("image", mime, data) == nil
	case "image/webp":
		valid = len(data) >= 16 && string(data[:4]) == "RIFF" && string(data[8:12]) == "WEBP" && http.DetectContentType(data) == mime
	case "application/pdf":
		valid = bytes.HasPrefix(data, []byte("%PDF-"))
	case "text/plain", "text/csv":
		text := strings.ToLower(strings.TrimSpace(string(data[:min(len(data), 1024)])))
		valid = strings.HasPrefix(http.DetectContentType(data), "text/plain") && !strings.Contains(text, "<svg") && !strings.Contains(text, "<html") && !strings.Contains(text, "<script")
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.openxmlformats-officedocument.presentationml.presentation":
		reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
		if err == nil && len(reader.File) <= 2000 {
			wanted := map[string]string{"application/vnd.openxmlformats-officedocument.wordprocessingml.document": "word/document.xml", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xl/workbook.xml", "application/vnd.openxmlformats-officedocument.presentationml.presentation": "ppt/presentation.xml"}[mime]
			for _, file := range reader.File {
				if file.Name == wanted {
					valid = true
					break
				}
			}
		}
	}
	if !valid {
		return fail(422, "unsupported_file", "支持PNG/JPEG/GIF/WebP、PDF、TXT/CSV及DOCX/XLSX/PPTX；文件实际内容须与类型一致")
	}
	return nil
}
func (s *Service) newPurchaseFile(actor Actor, input PurchaseAttachmentInput) (PurchaseFile, error) {
	if len(input.DataBase64) > base64.StdEncoding.EncodedLen(purchaseFileMaxBytes) {
		return PurchaseFile{}, fail(413, "file_too_large", "单附件最多8MiB")
	}
	data, err := base64.StdEncoding.Strict().DecodeString(input.DataBase64)
	if err != nil || len(data) == 0 {
		return PurchaseFile{}, fail(422, "invalid_file", "请选择有效文件原件")
	}
	if len(data) > purchaseFileMaxBytes {
		return PurchaseFile{}, fail(413, "file_too_large", "单附件最多8MiB")
	}
	if err := validPurchaseFile(input.Name, input.MIME, data); err != nil {
		return PurchaseFile{}, err
	}
	return PurchaseFile{ID: randomID("purchase_file_"), Name: input.Name, MIME: input.MIME, Size: len(data), DataBase64: input.DataBase64, UploaderID: actor.ID, CreatedAt: nowString(s.now())}, nil
}
func validatePurchaseFileSet(files []PurchaseFile) error {
	if len(files) > 8 {
		return fail(413, "attachment_limit", "每张采购单最多8个附件")
	}
	total := 0
	ids := map[string]bool{}
	for _, file := range files {
		if file.ID == "" || ids[file.ID] || file.Size < 1 || file.Size > purchaseFileMaxBytes || len(file.DataBase64) > base64.StdEncoding.EncodedLen(purchaseFileMaxBytes) {
			return fmt.Errorf("invalid private purchase attachment")
		}
		data, err := base64.StdEncoding.Strict().DecodeString(file.DataBase64)
		if err != nil || len(data) != file.Size || validPurchaseFile(file.Name, file.MIME, data) != nil {
			return fmt.Errorf("invalid private purchase attachment payload")
		}
		ids[file.ID] = true
		total += file.Size
	}
	if total > 32*1024*1024 {
		return fail(413, "attachment_limit", "每张采购单附件合计最多32MiB")
	}
	return nil
}
func (s *Service) registerInventoryRoutes(protected func(string, func(http.ResponseWriter, *http.Request, Actor))) {
	protected("GET /api/v38/parts/{id}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		if !internal(actor) {
			writeFailure(w, fail(403, "forbidden", "当前角色无库存明细权限"))
			return
		}
		part, err := findPart(&s.state, r.PathValue("id"))
		if err != nil {
			writeFailure(w, err)
			return
		}
		loans, purchases := []Loan{}, []Purchase{}
		for _, loan := range s.state.Loans {
			if loan.PartID == part.ID && (actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "dispatcher" || actor.Role == "engineer" && loan.BorrowerID == actor.ID) {
				loans = append(loans, loanView(loan))
			}
		}
		for _, purchase := range s.state.Purchases {
			if purchase.PartID == part.ID && canReadPurchase(purchase, actor) {
				purchases = append(purchases, purchaseView(purchase))
			}
		}
		writeJSON(w, 200, map[string]any{"part": *part, "loans": loans, "purchases": purchases})
	})
	protected("GET /api/v38/purchases/{id}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		purchase, err := findPurchase(&s.state, actor, r.PathValue("id"))
		if err != nil {
			writeFailure(w, err)
			return
		}
		writeJSON(w, 200, purchaseView(*purchase))
	})
	protected("POST /api/v38/purchases/{id}/attachments", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			if err := roles(actor, "admin", "warehouse", "dispatcher"); err != nil {
				return nil, err
			}
			var input struct {
				Version    int    `json:"version"`
				Name       string `json:"name"`
				MIME       string `json:"mime"`
				DataBase64 string `json:"dataBase64"`
			}
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			purchase, err := findPurchase(state, actor, r.PathValue("id"))
			if err != nil {
				return nil, err
			}
			if err := versionCheck(purchase.Version, input.Version); err != nil {
				return nil, err
			}
			file, err := s.newPurchaseFile(actor, PurchaseAttachmentInput{input.Name, input.MIME, input.DataBase64})
			if err != nil {
				return nil, err
			}
			purchase.Files = append(purchase.Files, file)
			if err := validatePurchaseFileSet(purchase.Files); err != nil {
				return nil, err
			}
			purchase.Version++
			s.appendAudit(state, actor, "purchase_attachment_add", purchase.ID, "success")
			return purchaseView(*purchase), nil
		})
	})
	protected("GET /api/v38/purchases/{id}/attachments/{fileId}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		purchase, err := findPurchase(&s.state, actor, r.PathValue("id"))
		if err != nil {
			writeFailure(w, err)
			return
		}
		for _, file := range purchase.Files {
			if file.ID == r.PathValue("fileId") {
				if err := s.auditLocked(actor, "purchase_attachment_read", purchase.ID, "success", file.ID); err != nil {
					writeFailure(w, err)
					return
				}
				data, err := base64.StdEncoding.Strict().DecodeString(file.DataBase64)
				if err != nil {
					writeFailure(w, err)
					return
				}
				w.Header().Set("Content-Type", file.MIME)
				w.Header().Set("Cache-Control", "no-store")
				w.Header().Set("Content-Disposition", "attachment; filename*=UTF-8''"+urlPathEscape(filepath.Base(file.Name)))
				w.WriteHeader(200)
				_, _ = w.Write(data)
				return
			}
		}
		writeFailure(w, fail(404, "not_found", "附件不存在或无访问权限"))
	})
}
