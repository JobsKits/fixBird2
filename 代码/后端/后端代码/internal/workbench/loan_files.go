// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"bytes"
	"encoding/base64"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"net/http"
	"path/filepath"
)

type LoanFile struct {
	PurchaseFile
	Stage     string `json:"stage"`
	Quantity  int    `json:"quantity"`
	Condition string `json:"condition,omitempty"`
	Note      string `json:"note,omitempty"`
}

func loanView(loan Loan) Loan {
	loan.Files = append([]LoanFile(nil), loan.Files...)
	for i := range loan.Files {
		loan.Files[i].DataBase64 = ""
	}
	return loan
}

func canReadLoan(loan Loan, actor Actor) bool {
	return actor.Role == "admin" || actor.Role == "warehouse" || actor.Role == "dispatcher" || actor.Role == "engineer" && loan.BorrowerID == actor.ID
}

func findLoan(state *State, actor Actor, id string) (*Loan, error) {
	for i := range state.Loans {
		if state.Loans[i].ID == id && canReadLoan(state.Loans[i], actor) {
			return &state.Loans[i], nil
		}
	}
	return nil, fail(404, "not_found", "借用记录不存在或无访问权限")
}

func validateLoanImage(file PurchaseFile) error {
	if file.MIME != "image/png" && file.MIME != "image/jpeg" && file.MIME != "image/gif" {
		return fail(422, "unsupported_image", "借还凭据仅支持PNG、JPEG或GIF图片原件")
	}
	data, err := base64.StdEncoding.Strict().DecodeString(file.DataBase64)
	if err != nil {
		return fail(422, "invalid_image", "图片原件编码无效")
	}
	config, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil || config.Width < 1 || config.Height < 1 || config.Width > 8192 || config.Height > 8192 || int64(config.Width)*int64(config.Height) > 32_000_000 {
		return fail(422, "invalid_image", "图片须为有效原件，单边最多8192像素、总像素最多3200万")
	}
	return nil
}

func validateLoanFiles(files []LoanFile, quantity int) error {
	if len(files) > 8 {
		return fail(413, "attachment_limit", "每张借用单最多8张图片，合计最多32MiB")
	}
	plain := make([]PurchaseFile, 0, len(files))
	total := 0
	for _, file := range files {
		if (file.Stage != "borrow" && file.Stage != "return") || file.Quantity < 1 || file.Quantity > quantity || !textValid(file.Note, 0, 2000) || file.Stage == "return" && file.Condition != "good" && file.Condition != "quarantine" {
			return fail(422, "invalid_attachment_context", "借还图片须关联真实阶段、数量和归还成色")
		}
		if err := validateLoanImage(file.PurchaseFile); err != nil {
			return err
		}
		plain = append(plain, file.PurchaseFile)
		total += file.Size
	}
	if total > 32*1024*1024 {
		return fail(413, "attachment_limit", "每张借用单图片合计最多32MiB")
	}
	return validatePurchaseFileSet(plain)
}

func (s *Service) appendLoanFiles(loan *Loan, actor Actor, inputs []PurchaseAttachmentInput, stage string, quantity int, condition, note string) error {
	if inputs == nil {
		return nil // Old clients omit this field; new native forms submit actual proof.
	}
	if len(inputs) == 0 {
		return fail(422, "attachment_required", "请至少选择一张实际借出或归还图片凭据")
	}
	if len(loan.Files)+len(inputs) > 8 {
		return fail(413, "attachment_limit", "每张借用单最多8张图片，合计最多32MiB")
	}
	files := append([]LoanFile(nil), loan.Files...)
	for _, input := range inputs {
		file, err := s.newPurchaseFile(actor, input)
		if err != nil {
			return err
		}
		file.ID = randomID("loan_file_")
		files = append(files, LoanFile{PurchaseFile: file, Stage: stage, Quantity: quantity, Condition: condition, Note: note})
	}
	if err := validateLoanFiles(files, loan.Quantity); err != nil {
		return err
	}
	loan.Files = files
	return nil
}

func (s *Service) registerLoanFileRoutes(protected func(string, func(http.ResponseWriter, *http.Request, Actor))) {
	protected("POST /api/v38/loans/{id}/files", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.write(w, r, actor, 200, func(state *State, raw []byte) (any, error) {
			if err := roles(actor, "admin", "warehouse"); err != nil {
				return nil, err
			}
			var input struct {
				Version     int                       `json:"version"`
				Stage       string                    `json:"stage"`
				Quantity    int                       `json:"quantity"`
				Condition   string                    `json:"condition"`
				Note        string                    `json:"note"`
				Attachments []PurchaseAttachmentInput `json:"attachments"`
			}
			if err := decodeStrict(raw, &input); err != nil {
				return nil, err
			}
			loan, err := findLoan(state, actor, r.PathValue("id"))
			if err != nil {
				return nil, err
			}
			if err := versionCheck(loan.Version, input.Version); err != nil {
				return nil, err
			}
			if input.Attachments == nil || input.Quantity < 1 || input.Quantity > loan.Quantity || input.Stage != "borrow" && input.Stage != "return" {
				return nil, fail(422, "attachment_required", "请填写真实阶段、数量并选择图片凭据")
			}
			if input.Stage == "return" {
				returned := loan.ReturnedGood
				if input.Condition == "quarantine" {
					returned = loan.ReturnedQuarantine
				}
				if input.Quantity > returned {
					return nil, fail(422, "invalid_attachment_context", "补录数量不能超过已实际归还数量")
				}
			}
			if err := s.appendLoanFiles(loan, actor, input.Attachments, input.Stage, input.Quantity, input.Condition, input.Note); err != nil {
				return nil, err
			}
			loan.Version++
			s.appendAudit(state, actor, "loan_attachment_add", loan.ID, "success")
			return loanView(*loan), nil
		})
	})
	protected("GET /api/v38/loans/{id}/files/{fileId}", func(w http.ResponseWriter, r *http.Request, actor Actor) {
		s.mu.Lock()
		defer s.mu.Unlock()
		actor, err := s.currentActorLocked(actor)
		if err != nil {
			writeFailure(w, err)
			return
		}
		loan, err := findLoan(&s.state, actor, r.PathValue("id"))
		if err != nil {
			writeFailure(w, err)
			return
		}
		for _, file := range loan.Files {
			if file.ID != r.PathValue("fileId") {
				continue
			}
			if err := s.auditLocked(actor, "loan_attachment_read", loan.ID, "success", file.ID); err != nil {
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
		writeFailure(w, fail(404, "not_found", "图片凭据不存在或无访问权限"))
	})
}
