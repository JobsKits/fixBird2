package ledger

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"io"
	"strconv"
	"strings"
)

type Service struct{ store Store }

func NewService(store Store) *Service                    { return &Service{store: store} }
func (service *Service) Ready(ctx context.Context) error { return service.store.Ready(ctx) }
func (service *Service) Get(ctx context.Context, id string) (Journal, error) {
	return service.store.Get(ctx, id)
}

func (service *Service) List(ctx context.Context, query Query) (Page, error) {
	query, err := NormalizeQuery(query)
	if err != nil {
		return Page{}, err
	}
	items, err := service.store.List(ctx, query)
	if err != nil {
		return Page{}, err
	}
	page := Page{Items: items}
	if page.Items == nil {
		page.Items = []Journal{}
	}
	if len(items) > query.Limit {
		page.Items = items[:query.Limit]
		last := page.Items[len(page.Items)-1]
		data, _ := json.Marshal(Cursor{OccurredAt: last.OccurredAt, ID: last.ID})
		page.NextCursor = base64.RawURLEncoding.EncodeToString(data)
	}
	return page, nil
}

func DecodeCursor(value string) (*Cursor, error) {
	if value == "" {
		return nil, nil
	}
	if len(value) > 512 {
		return nil, ErrInvalidInput
	}
	data, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, ErrInvalidInput
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var cursor Cursor
	if err := decoder.Decode(&cursor); err != nil || cursor.OccurredAt.IsZero() || !identifier.MatchString(cursor.ID) {
		return nil, ErrInvalidInput
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return nil, ErrInvalidInput
	}
	return &cursor, nil
}

func (service *Service) Summary(ctx context.Context, query Query) (Summary, error) {
	query, err := NormalizeQuery(query)
	if err != nil {
		return Summary{}, err
	}
	return service.store.Summary(ctx, query)
}

// Return complete bounded output before HTTP headers; oversize exports fail rather than silently truncate.
func (service *Service) ExportCSV(ctx context.Context, query Query) ([]byte, error) {
	query, err := NormalizeQuery(query)
	if err != nil || query.Before != nil {
		return nil, ErrInvalidInput
	}
	items, err := service.store.Snapshot(ctx, query, MaxExportJournals+1)
	if err != nil {
		return nil, err
	}
	if len(items) > MaxExportJournals {
		return nil, ErrExportTooLarge
	}
	var output bytes.Buffer
	output.WriteString("\xef\xbb\xbf")
	writer := csv.NewWriter(&output)
	header := []string{"journal_id", "event_key", "mode", "simulated", "kind", "channel", "status", "order_id", "customer_id", "worker_id", "settlement_id", "occurred_at", "created_at", "actor_id", "reason", "reversal_of_id", "account", "direction", "amount_cents"}
	if err := writer.Write(header); err != nil {
		return nil, err
	}
	for _, journal := range items {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		for _, entry := range journal.Entries {
			row := []string{journal.ID, journal.EventKey, journal.Mode, strconv.FormatBool(journal.Simulated), journal.Kind, journal.Channel, journal.Status,
				journal.OrderID, journal.CustomerID, journal.WorkerID, journal.SettlementID, journal.OccurredAt.Format("2006-01-02T15:04:05.000Z07:00"),
				journal.CreatedAt.Format("2006-01-02T15:04:05.000Z07:00"), journal.ActorID, journal.Reason, journal.ReversalOfID, entry.Account, entry.Direction}
			for index := range row {
				row[index] = csvText(row[index])
			}
			row = append(row, strconv.FormatInt(entry.AmountCents, 10))
			if err := writer.Write(row); err != nil {
				return nil, err
			}
		}
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, err
	}
	return output.Bytes(), nil
}

// Spreadsheet formula markers in free text must stay literal after CSV is opened in Excel.
func csvText(value string) string {
	trimmed := strings.TrimLeft(value, " \t\r\n")
	if trimmed != "" && strings.ContainsRune("=+-@", rune(trimmed[0])) {
		return "'" + value
	}
	return value
}

func (service *Service) RecordCollection(ctx context.Context, input Collection) (Journal, error) {
	journal, err := NewCollection(input)
	if err != nil {
		return Journal{}, err
	}
	return service.store.Append(ctx, journal)
}
func (service *Service) RecordPayout(ctx context.Context, input Payout) (Journal, error) {
	journal, err := NewPayout(input)
	if err != nil {
		return Journal{}, err
	}
	return service.store.Append(ctx, journal)
}
