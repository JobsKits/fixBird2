// Package workbench implements the Jobs-maintained V3.8 business workbench.
package workbench

import (
	"encoding/json"
	"time"
)

type Persistence interface {
	Load() ([]byte, error)
	Save([]byte) error
}

type Actor struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	Name        string `json:"name"`
	Role        string `json:"role"`
	CompanyID   string `json:"companyId"`
	Status      string `json:"status"`
	AuthVersion int    `json:"authVersion"`
}

type Account struct {
	Actor Actor  `json:"actor"`
	Salt  string `json:"salt"`
	Hash  string `json:"hash"`
}

type Quote struct {
	Version                 int    `json:"version"`
	AmountCents             int64  `json:"amountCents"`
	Description             string `json:"description"`
	WarrantyMonths          int    `json:"warrantyMonths"`
	PaymentTerms            string `json:"paymentTerms"`
	PrepayCents             int64  `json:"prepayCents"`
	StartRequiresPrepayment bool   `json:"startRequiresPrepayment"`
	ValidUntil              string `json:"validUntil"`
	Approved                bool   `json:"approved"`
	Signed                  bool   `json:"signed"`
	Signature               string `json:"signature,omitempty"`
	Signer                  string `json:"signer,omitempty"`
	SignedAt                string `json:"signedAt,omitempty"`
	AutoAccept              bool   `json:"autoAccept"`
}

type Documents struct {
	Requirement string   `json:"requirement"`
	Reason      string   `json:"reason"`
	Version     int      `json:"version"`
	Prepared    bool     `json:"prepared"`
	Sent        bool     `json:"sent"`
	Recipient   string   `json:"recipient"`
	Files       []string `json:"files"`
}

type Invoice struct {
	ID          string   `json:"id"`
	Number      string   `json:"number"`
	AmountCents int64    `json:"amountCents"`
	Files       []string `json:"files"`
	Voided      bool     `json:"voided"`
	VoidReason  string   `json:"voidReason,omitempty"`
}

type Cash struct {
	ID          string `json:"id"`
	AmountCents int64  `json:"amountCents"`
	Kind        string `json:"kind"`
	Purpose     string `json:"purpose"`
	Receipt     string `json:"receipt"`
	Collector   string `json:"collector"`
	OccurredAt  string `json:"occurredAt"`
	Verified    bool   `json:"verified"`
	HandedOver  bool   `json:"handedOver"`
	VerifiedBy  string `json:"verifiedBy,omitempty"`
}

type Evidence struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Kind         string `json:"kind"`
	Text         string `json:"text"`
	MIME         string `json:"mime"`
	UploaderID   string `json:"uploaderId"`
	CreatedAt    string `json:"createdAt"`
	Deleted      bool   `json:"deleted"`
	Stage        string `json:"stage"`
	Data         string `json:"data,omitempty"`
	Public       bool   `json:"public"`
	SHA256       string `json:"sha256,omitempty"`
	DeleteReason string `json:"deleteReason,omitempty"`
}

type Event struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Title     string `json:"title"`
	Note      string `json:"note"`
	ActorID   string `json:"actorId"`
	ActorName string `json:"actorName"`
	At        string `json:"at"`
	Version   int    `json:"version"`
	Internal  bool   `json:"internal"`
}

type Visit struct {
	ID        string `json:"id"`
	PlannedAt string `json:"plannedAt"`
	FeeMemo   string `json:"feeMemo"`
	Note      string `json:"note"`
	StartedAt string `json:"startedAt,omitempty"`
}

type Outsource struct {
	ID          string `json:"id"`
	Provider    string `json:"provider"`
	Contact     string `json:"contact"`
	Destination string `json:"destination"`
	Note        string `json:"note"`
}

type Cost struct {
	ID          string `json:"id"`
	Category    string `json:"category"`
	AmountCents int64  `json:"amountCents"`
	Note        string `json:"note"`
	Approved    bool   `json:"approved"`
	OwnerID     string `json:"ownerId"`
}

type Commission struct {
	ID          string `json:"id"`
	Person      string `json:"person"`
	AmountCents int64  `json:"amountCents"`
	Note        string `json:"note"`
	Settled     bool   `json:"settled"`
}

type Task struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	OwnerID    string `json:"ownerId"`
	DueAt      string `json:"dueAt"`
	Resolved   bool   `json:"resolved"`
	Resolution string `json:"resolution,omitempty"`
}

type Warranty struct {
	StartsAt string `json:"startsAt"`
	EndsAt   string `json:"endsAt"`
}

// Each submitted acceptance is retained independently of later resolutions.
type AcceptanceRecord struct {
	ID           string `json:"id"`
	Passed       bool   `json:"passed"`
	Signature    string `json:"signature"`
	SignerID     string `json:"signerId"`
	SignerName   string `json:"signerName"`
	SignedAt     string `json:"signedAt"`
	Note         string `json:"note"`
	QuoteVersion int    `json:"quoteVersion"`
	OrderVersion int    `json:"orderVersion"`
	IssueID      string `json:"issueId,omitempty"`
}

type Summary struct {
	DocumentStatus   string   `json:"documentStatus"`
	InvoiceStatus    string   `json:"invoiceStatus"`
	CollectedCents   int64    `json:"collectedCents"`
	ReceivableCents  int64    `json:"receivableCents"`
	RemainingCents   int64    `json:"remainingCents"`
	OverpaidCents    int64    `json:"overpaidCents"`
	PendingCashCents int64    `json:"pendingCashCents"`
	InvoiceCents     int64    `json:"invoiceCents"`
	NextTask         string   `json:"nextTask"`
	Missing          []string `json:"missing"`
	WarrantyLabel    string   `json:"warrantyLabel"`
}

type Order struct {
	ID                  string             `json:"id"`
	Number              string             `json:"number"`
	Version             int                `json:"version"`
	Type                string             `json:"type"`
	Customer            string             `json:"customer"`
	CustomerID          string             `json:"customerId"`
	CompanyID           string             `json:"companyId"`
	Project             string             `json:"project"`
	Device              string             `json:"device"`
	Description         string             `json:"description"`
	Status              string             `json:"status"`
	Outcome             string             `json:"outcome"`
	OwnerID             string             `json:"ownerId"`
	AssigneeID          string             `json:"assigneeId"`
	CreatedAt           string             `json:"createdAt"`
	UpdatedAt           string             `json:"updatedAt"`
	Remark              string             `json:"remark"`
	CustomerNote        string             `json:"customerNote"`
	Quote               Quote              `json:"quote"`
	QuoteHistory        []Quote            `json:"quoteHistory"`
	Documents           Documents          `json:"documents"`
	InvoiceRequirement  string             `json:"invoiceRequirement"`
	InvoiceReason       string             `json:"invoiceReason"`
	InvoiceDueCents     int64              `json:"invoiceDueCents"`
	Invoices            []Invoice          `json:"invoices"`
	Cash                []Cash             `json:"cash"`
	Evidence            []Evidence         `json:"evidence"`
	Events              []Event            `json:"events"`
	Visits              []Visit            `json:"visits"`
	Outsource           []Outsource        `json:"outsource"`
	Costs               []Cost             `json:"costs"`
	Commissions         []Commission       `json:"commissions"`
	Issues              []Task             `json:"issues"`
	Obligations         []Task             `json:"obligations"`
	Warranty            Warranty           `json:"warranty"`
	OriginalOrderID     string             `json:"originalOrderId"`
	Summary             Summary            `json:"summary"`
	ReceivableCents     int64              `json:"receivableCents"`
	DeliveredAt         string             `json:"deliveredAt,omitempty"`
	AcceptanceDueAt     string             `json:"acceptanceDueAt,omitempty"`
	AcceptedAt          string             `json:"acceptedAt,omitempty"`
	AcceptanceSignature string             `json:"acceptanceSignature,omitempty"`
	AcceptanceRecords   []AcceptanceRecord `json:"acceptanceRecords,omitempty"`
	AcceptanceMode      string             `json:"acceptanceMode,omitempty"`
	FailureReason       string             `json:"failureReason,omitempty"`
	CompletionAt        string             `json:"completionAt,omitempty"`
	CompletionBy        string             `json:"completionBy,omitempty"`
	CompletionVersion   int                `json:"completionVersion,omitempty"`
	CompletionChecks    []string           `json:"completionChecks"`
	RestartReview       bool               `json:"restartReview"`
	AllowedActions      []string           `json:"allowedActions"`
	IsSummary           bool               `json:"isSummary,omitempty"`
}

type Part struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	SKU        string `json:"sku"`
	Available  int    `json:"available"`
	Quarantine int    `json:"quarantine"`
}

type LoanTransfer struct {
	Quantity int    `json:"quantity"`
	OwnerID  string `json:"ownerId"`
	DueAt    string `json:"dueAt"`
	Reason   string `json:"reason"`
	At       string `json:"at"`
}

type Loan struct {
	ID                 string         `json:"id"`
	Version            int            `json:"version"`
	OrderID            string         `json:"orderId"`
	PartID             string         `json:"partId"`
	PartName           string         `json:"partName"`
	Quantity           int            `json:"quantity"`
	ReturnedGood       int            `json:"returnedGood"`
	ReturnedQuarantine int            `json:"returnedQuarantine"`
	Consumed           int            `json:"consumed"`
	Disposed           int            `json:"disposed"`
	Outstanding        int            `json:"outstanding"`
	BorrowerID         string         `json:"borrowerId"`
	DueAt              string         `json:"dueAt"`
	Note               string         `json:"note"`
	Transfers          []LoanTransfer `json:"transfers"`
}

type Purchase struct {
	ID        string `json:"id"`
	Version   int    `json:"version"`
	Supplier  string `json:"supplier"`
	PartID    string `json:"partId"`
	Quantity  int    `json:"quantity"`
	Received  int    `json:"received"`
	UnitCents int64  `json:"unitCents"`
	Note      string `json:"note"`
}

type Settings struct {
	CompanyAddress  string `json:"companyAddress"`
	CompanyReceiver string `json:"companyReceiver"`
	CompanyPhone    string `json:"companyPhone"`
	ReminderHours   int    `json:"reminderHours"`
	RemarkLimit     int    `json:"remarkLimit"`
	Demo            bool   `json:"demo"`
}

type CachedRequest struct {
	Hash          string          `json:"hash"`
	Status        int             `json:"status"`
	Body          json.RawMessage `json:"body"`
	At            time.Time       `json:"at"`
	RecoveryState string          `json:"recoveryState,omitempty"`
}

type State struct {
	Schema    int                      `json:"schema"`
	Accounts  []Account                `json:"accounts"`
	Orders    []Order                  `json:"orders"`
	Parts     []Part                   `json:"parts"`
	Loans     []Loan                   `json:"loans"`
	Purchases []Purchase               `json:"purchases"`
	Settings  Settings                 `json:"settings"`
	Requests  map[string]CachedRequest `json:"idempotency"`
	Audit     []AuditEvent             `json:"audit"`
}

type StateDefinition struct {
	Code  string `json:"code"`
	Label string `json:"label"`
}

var States = []StateDefinition{
	{"pending_intake", "待受理"}, {"pending_arrangement", "待安排"},
	{"diagnosis_quotation", "检测／报价中"}, {"pending_customer_confirmation", "待客户确认"},
	{"pending_execution", "待执行"}, {"repairing", "维修中"},
	{"pending_quality_check", "待质检"}, {"pending_delivery", "待交付"},
	{"pending_acceptance", "待验收"}, {"settling", "结算中"},
	{"pending_completion", "待完结确认"}, {"completed", "已完结"},
}
