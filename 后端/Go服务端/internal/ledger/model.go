// Package ledger records immutable, balanced journals. Simulated records never prove money moved.
package ledger

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
	"time"
)

const (
	ModeSimulated           = "simulated"
	ModeActual              = "actual"
	KindCollection          = "collection"
	KindPayout              = "manual_payout"
	KindReversal            = "reversal"
	StatusPosted            = "posted"
	StatusReversed          = "reversed"
	ChannelDemo             = "demo"
	ChannelManual           = "manual"
	AccountFunds            = "platform_funds"
	AccountPayable          = "worker_payable"
	AccountRevenue          = "platform_revenue"
	Debit                   = "debit"
	Credit                  = "credit"
	MaxAmountCents    int64 = 100000000
	DefaultPageSize         = 50
	MaxPageSize             = 200
	MaxExportJournals       = 10000
)

var (
	ErrInvalidInput        = errors.New("invalid ledger input")
	ErrNotFound            = errors.New("ledger journal not found")
	ErrInvalidState        = errors.New("ledger state conflict")
	ErrIdempotencyConflict = errors.New("ledger event key has different financial content")
	ErrRealNotConfigured   = errors.New("real payment accounting is not configured")
	ErrUncertain           = errors.New("ledger transaction outcome is uncertain; retry the identical event")
	ErrAmountOverflow      = errors.New("ledger total exceeds integer range")
	ErrExportTooLarge      = errors.New("export exceeds 10000 journals; narrow the filter")
	identifier             = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,64}$`)
)

type Entry struct {
	Account     string `json:"account"`
	Direction   string `json:"direction"`
	AmountCents int64  `json:"amountCents"`
}

type Journal struct {
	ID               string    `json:"id"`
	EventKey         string    `json:"eventKey"`
	Fingerprint      string    `json:"-"`
	OrderID          string    `json:"orderId"`
	CustomerID       string    `json:"customerId"`
	WorkerID         string    `json:"workerId"`
	SettlementID     string    `json:"settlementId"`
	Mode             string    `json:"mode"`
	Simulated        bool      `json:"simulated"`
	Kind             string    `json:"kind"`
	Channel          string    `json:"channel"`
	Status           string    `json:"status"`
	AmountCents      int64     `json:"amountCents"`
	WorkerShareCents int64     `json:"workerShareCents"`
	PlatformFeeCents int64     `json:"platformFeeCents"`
	OccurredAt       time.Time `json:"occurredAt"`
	CreatedAt        time.Time `json:"createdAt"`
	ActorID          string    `json:"actorId"`
	Reason           string    `json:"reason"`
	ReversalOfID     string    `json:"reversalOfId"`
	Entries          []Entry   `json:"entries"`
}

type Collection struct {
	OrderID, CustomerID, WorkerID, SettlementID     string
	Mode, Channel, ActorID, Reason                  string
	AmountCents, WorkerShareCents, PlatformFeeCents int64
	OccurredAt                                      time.Time
}

type Payout struct {
	OrderID, CustomerID, WorkerID, SettlementID string
	Mode, Channel, ActorID, Reason              string
	AmountCents                                 int64
	OccurredAt                                  time.Time
}

type Cursor struct {
	OccurredAt time.Time `json:"occurredAt"`
	ID         string    `json:"id"`
}

// Time range is [From, To). Account totals describe filtered movement, not a bank balance.
type Query struct {
	Mode, Kind, Status, Channel   string
	OrderID, CustomerID, WorkerID string
	From, To                      time.Time
	Limit                         int
	Before                        *Cursor
}

type Page struct {
	Items      []Journal `json:"items"`
	NextCursor string    `json:"nextCursor"`
}

type Summary struct {
	Mode                 string `json:"mode"`
	Simulated            bool   `json:"simulated"`
	Currency             string `json:"currency"`
	Scope                string `json:"scope"`
	JournalCount         int64  `json:"journalCount"`
	CollectedCents       int64  `json:"collectedCents"`
	WorkerAccruedCents   int64  `json:"workerAccruedCents"`
	PlatformRevenueCents int64  `json:"platformRevenueCents"`
	PayoutCents          int64  `json:"payoutCents"`
	PlatformFundsCents   int64  `json:"platformFundsCents"`
	WorkerPayableCents   int64  `json:"workerPayableCents"`
}

func CollectionEventKey(mode, orderID string) string  { return "collection:" + mode + ":" + orderID }
func PayoutEventKey(mode, settlementID string) string { return "payout:" + mode + ":" + settlementID }

// Collection and split are one balanced journal; no mutable balance is maintained.
func NewCollection(input Collection) (Journal, error) {
	journal := baseJournal(input.OrderID, input.CustomerID, input.WorkerID, input.SettlementID, input.Mode, input.ActorID, input.Reason, input.OccurredAt)
	journal.Kind, journal.Channel = KindCollection, defaultString(input.Channel, ChannelDemo)
	journal.EventKey = CollectionEventKey(journal.Mode, journal.OrderID)
	journal.AmountCents, journal.WorkerShareCents, journal.PlatformFeeCents = input.AmountCents, input.WorkerShareCents, input.PlatformFeeCents
	journal.Entries = []Entry{{AccountFunds, Debit, input.AmountCents}}
	if input.WorkerShareCents > 0 {
		journal.Entries = append(journal.Entries, Entry{AccountPayable, Credit, input.WorkerShareCents})
	}
	if input.PlatformFeeCents > 0 {
		journal.Entries = append(journal.Entries, Entry{AccountRevenue, Credit, input.PlatformFeeCents})
	}
	return finalize(journal)
}

// Manual payout is a simulated attestation; it never initiates a transfer.
func NewPayout(input Payout) (Journal, error) {
	journal := baseJournal(input.OrderID, input.CustomerID, input.WorkerID, input.SettlementID, input.Mode, input.ActorID, input.Reason, input.OccurredAt)
	journal.Kind, journal.Channel = KindPayout, defaultString(input.Channel, ChannelManual)
	journal.EventKey = PayoutEventKey(journal.Mode, journal.SettlementID)
	journal.AmountCents, journal.WorkerShareCents = input.AmountCents, input.AmountCents
	journal.Entries = []Entry{{AccountPayable, Debit, input.AmountCents}, {AccountFunds, Credit, input.AmountCents}}
	return finalize(journal)
}

// Internal only: a caller must reverse related business state in the same transaction before exposing this action.
func NewReversal(original Journal, eventKey, actorID, reason string, occurredAt time.Time) (Journal, error) {
	if original.Kind == KindReversal || original.Status == StatusReversed || !identifier.MatchString(original.ID) {
		return Journal{}, ErrInvalidState
	}
	if strings.TrimSpace(reason) == "" {
		return Journal{}, fmt.Errorf("%w: a reversal reason is required", ErrInvalidInput)
	}
	if len(eventKey) > 191 || eventKey == "" {
		return Journal{}, fmt.Errorf("%w: invalid reversal event key", ErrInvalidInput)
	}
	journal := baseJournal(original.OrderID, original.CustomerID, original.WorkerID, original.SettlementID, original.Mode, actorID, reason, occurredAt)
	journal.Kind, journal.Channel, journal.EventKey = KindReversal, original.Channel, eventKey
	journal.ReversalOfID = original.ID
	journal.AmountCents, journal.WorkerShareCents, journal.PlatformFeeCents = original.AmountCents, original.WorkerShareCents, original.PlatformFeeCents
	journal.Entries = append([]Entry(nil), original.Entries...)
	for index := range journal.Entries {
		if journal.Entries[index].Direction == Debit {
			journal.Entries[index].Direction = Credit
		} else {
			journal.Entries[index].Direction = Debit
		}
	}
	return finalize(journal)
}

func baseJournal(orderID, customerID, workerID, settlementID, mode, actorID, reason string, occurredAt time.Time) Journal {
	now := time.Now().UTC().Truncate(time.Millisecond)
	if occurredAt.IsZero() {
		occurredAt = now
	}
	return Journal{OrderID: orderID, CustomerID: customerID, WorkerID: workerID, SettlementID: settlementID,
		Mode: defaultString(mode, ModeSimulated), Simulated: true, ActorID: defaultString(actorID, "system"), Reason: reason,
		Status: StatusPosted, OccurredAt: occurredAt.UTC().Truncate(time.Millisecond), CreatedAt: now}
}

func defaultString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func finalize(journal Journal) (Journal, error) {
	keyHash := sha256.Sum256([]byte(journal.EventKey))
	journal.ID = "led_" + hex.EncodeToString(keyHash[:16])
	journal.Fingerprint = fingerprint(journal)
	if err := ValidateJournal(journal); err != nil {
		return Journal{}, err
	}
	return journal, nil
}

// Replays ignore clock/audit metadata; a changed amount, split or participant conflicts instead of overwriting.
func fingerprint(journal Journal) string {
	reason := ""
	if journal.Kind == KindReversal {
		reason = journal.Reason
	}
	data, _ := json.Marshal(struct {
		Order, Customer, Worker, Settlement, Mode, Kind, Channel, Original, Reason string
		Amount, Share, Fee                                                         int64
		Entries                                                                    []Entry
	}{journal.OrderID, journal.CustomerID, journal.WorkerID, journal.SettlementID, journal.Mode, journal.Kind, journal.Channel,
		journal.ReversalOfID, reason, journal.AmountCents, journal.WorkerShareCents, journal.PlatformFeeCents, journal.Entries})
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func ValidateJournal(journal Journal) error {
	if journal.Mode != ModeSimulated || !journal.Simulated {
		return ErrRealNotConfigured
	}
	for _, value := range []string{journal.ID, journal.OrderID, journal.CustomerID, journal.WorkerID, journal.SettlementID, journal.ActorID} {
		if !identifier.MatchString(value) {
			return fmt.Errorf("%w: invalid participant identifier", ErrInvalidInput)
		}
	}
	if journal.Status != StatusPosted || journal.OccurredAt.IsZero() || journal.CreatedAt.IsZero() || len(journal.Reason) > 512 ||
		journal.AmountCents < 1 || journal.AmountCents > MaxAmountCents || journal.WorkerShareCents < 1 || journal.WorkerShareCents > journal.AmountCents ||
		journal.PlatformFeeCents < 0 || journal.PlatformFeeCents != journal.AmountCents-journal.WorkerShareCents {
		return fmt.Errorf("%w: invalid amount, split or metadata", ErrInvalidInput)
	}
	if len(journal.EventKey) == 0 || len(journal.EventKey) > 191 || journal.Fingerprint != fingerprint(journal) {
		return ErrInvalidInput
	}
	keyHash := sha256.Sum256([]byte(journal.EventKey))
	if journal.ID != "led_"+hex.EncodeToString(keyHash[:16]) {
		return ErrInvalidInput
	}
	var expected []Entry
	switch journal.Kind {
	case KindCollection:
		if journal.Channel == "wechat" || journal.Channel == "alipay" || journal.Channel == "aggregate" {
			return ErrRealNotConfigured
		}
		if journal.Channel != ChannelDemo || journal.EventKey != CollectionEventKey(journal.Mode, journal.OrderID) || journal.ReversalOfID != "" {
			return ErrInvalidInput
		}
		expected = []Entry{{AccountFunds, Debit, journal.AmountCents}, {AccountPayable, Credit, journal.WorkerShareCents}}
		if journal.PlatformFeeCents > 0 {
			expected = append(expected, Entry{AccountRevenue, Credit, journal.PlatformFeeCents})
		}
	case KindPayout:
		if journal.Channel != ChannelManual || journal.EventKey != PayoutEventKey(journal.Mode, journal.SettlementID) || journal.PlatformFeeCents != 0 || journal.ReversalOfID != "" {
			return ErrInvalidInput
		}
		expected = []Entry{{AccountPayable, Debit, journal.AmountCents}, {AccountFunds, Credit, journal.AmountCents}}
	case KindReversal:
		if !identifier.MatchString(journal.ReversalOfID) || strings.TrimSpace(journal.Reason) == "" || (journal.Channel != ChannelDemo && journal.Channel != ChannelManual) {
			return ErrInvalidInput
		}
	default:
		return ErrInvalidInput
	}
	if expected != nil {
		if len(expected) != len(journal.Entries) {
			return ErrInvalidInput
		}
		for index := range expected {
			if expected[index] != journal.Entries[index] {
				return ErrInvalidInput
			}
		}
	}
	var debit, credit int64
	if len(journal.Entries) < 2 || len(journal.Entries) > 3 {
		return ErrInvalidInput
	}
	for _, entry := range journal.Entries {
		if entry.AmountCents < 1 || entry.AmountCents > MaxAmountCents || (entry.Account != AccountFunds && entry.Account != AccountPayable && entry.Account != AccountRevenue) {
			return ErrInvalidInput
		}
		if entry.Direction == Debit {
			debit += entry.AmountCents
		} else if entry.Direction == Credit {
			credit += entry.AmountCents
		} else {
			return ErrInvalidInput
		}
	}
	if debit != credit {
		return fmt.Errorf("%w: debit and credit differ", ErrInvalidInput)
	}
	return nil
}

func NormalizeQuery(query Query) (Query, error) {
	query.Mode = defaultString(query.Mode, ModeSimulated)
	if query.Mode != ModeSimulated && query.Mode != ModeActual {
		return Query{}, ErrInvalidInput
	}
	if query.Kind != "" && query.Kind != KindCollection && query.Kind != KindPayout && query.Kind != KindReversal {
		return Query{}, ErrInvalidInput
	}
	if query.Status != "" && query.Status != StatusPosted && query.Status != StatusReversed {
		return Query{}, ErrInvalidInput
	}
	if query.Channel != "" && query.Channel != ChannelDemo && query.Channel != ChannelManual && query.Channel != "wechat" && query.Channel != "alipay" && query.Channel != "aggregate" {
		return Query{}, ErrInvalidInput
	}
	for _, value := range []string{query.OrderID, query.CustomerID, query.WorkerID} {
		if value != "" && !identifier.MatchString(value) {
			return Query{}, ErrInvalidInput
		}
	}
	if !query.From.IsZero() && !query.To.IsZero() && !query.From.Before(query.To) {
		return Query{}, ErrInvalidInput
	}
	if query.Limit == 0 {
		query.Limit = DefaultPageSize
	}
	if query.Limit < 1 || query.Limit > MaxPageSize {
		return Query{}, ErrInvalidInput
	}
	if query.Before != nil && (query.Before.OccurredAt.IsZero() || !identifier.MatchString(query.Before.ID)) {
		return Query{}, ErrInvalidInput
	}
	return query, nil
}

func addCents(current, value int64) (int64, error) {
	if (value > 0 && current > math.MaxInt64-value) || (value < 0 && current < math.MinInt64-value) {
		return 0, ErrAmountOverflow
	}
	return current + value, nil
}

func subtractCents(current, value int64) (int64, error) {
	if (value > 0 && current < math.MinInt64+value) || (value < 0 && current > math.MaxInt64+value) {
		return 0, ErrAmountOverflow
	}
	return current - value, nil
}
