package ledger

import (
	"context"
	"sort"
	"sync"
)

type Memory struct {
	mu       sync.RWMutex
	byID     map[string]Journal
	byEvent  map[string]Journal
	reversed map[string]string
}

func NewMemory() *Memory {
	return &Memory{byID: make(map[string]Journal), byEvent: make(map[string]Journal), reversed: make(map[string]string)}
}
func (store *Memory) Ready(ctx context.Context) error { return ctx.Err() }
func clone(journal Journal) Journal {
	journal.Entries = append([]Entry(nil), journal.Entries...)
	return journal
}

func (store *Memory) withStatus(journal Journal) Journal {
	journal = clone(journal)
	journal.Status = StatusPosted
	if store.reversed[journal.ID] != "" {
		journal.Status = StatusReversed
	}
	return journal
}

func (store *Memory) Append(ctx context.Context, journal Journal) (Journal, error) {
	return store.AppendWith(ctx, journal, nil)
}

// apply is invoked under the journal lock after every check, before publication. It must not re-enter ledger.
// The business repository holds its own lock and performs its final no-fail state mutation in this callback.
func (store *Memory) AppendWith(ctx context.Context, journal Journal, apply func() error) (Journal, error) {
	if err := ctx.Err(); err != nil {
		return Journal{}, err
	}
	if err := ValidateJournal(journal); err != nil {
		return Journal{}, err
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if previous, exists := store.byEvent[journal.EventKey]; exists {
		if !sameFinancialEvent(previous, journal) {
			return Journal{}, ErrIdempotencyConflict
		}
		return store.withStatus(previous), nil
	}
	if _, exists := store.byID[journal.ID]; exists {
		return Journal{}, ErrIdempotencyConflict
	}
	if err := validateAgainstState(journal, store.byEvent, store.byID, store.reversed); err != nil {
		return Journal{}, err
	}
	if err := ctx.Err(); err != nil {
		return Journal{}, err
	}
	if apply != nil {
		if err := apply(); err != nil {
			return Journal{}, err
		}
	}
	journal = clone(journal)
	store.byID[journal.ID], store.byEvent[journal.EventKey] = journal, journal
	if journal.ReversalOfID != "" {
		store.reversed[journal.ReversalOfID] = journal.ID
	}
	return store.withStatus(journal), nil
}

func (store *Memory) Get(ctx context.Context, id string) (Journal, error) {
	if err := ctx.Err(); err != nil {
		return Journal{}, err
	}
	store.mu.RLock()
	defer store.mu.RUnlock()
	journal, exists := store.byID[id]
	if !exists {
		return Journal{}, ErrNotFound
	}
	return store.withStatus(journal), nil
}

func (store *Memory) GetEvent(ctx context.Context, key string) (Journal, error) {
	if err := ctx.Err(); err != nil {
		return Journal{}, err
	}
	store.mu.RLock()
	defer store.mu.RUnlock()
	journal, exists := store.byEvent[key]
	if !exists {
		return Journal{}, ErrNotFound
	}
	return store.withStatus(journal), nil
}

func matches(journal Journal, query Query) bool {
	return journal.Mode == query.Mode && (query.Kind == "" || journal.Kind == query.Kind) &&
		(query.Status == "" || journal.Status == query.Status) && (query.Channel == "" || journal.Channel == query.Channel) &&
		(query.OrderID == "" || journal.OrderID == query.OrderID) && (query.CustomerID == "" || journal.CustomerID == query.CustomerID) &&
		(query.WorkerID == "" || journal.WorkerID == query.WorkerID) && (query.From.IsZero() || !journal.OccurredAt.Before(query.From)) &&
		(query.To.IsZero() || journal.OccurredAt.Before(query.To)) && (query.Before == nil || journal.OccurredAt.Before(query.Before.OccurredAt) ||
		(journal.OccurredAt.Equal(query.Before.OccurredAt) && journal.ID < query.Before.ID))
}

func (store *Memory) listLocked(query Query) []Journal {
	items := make([]Journal, 0)
	for _, journal := range store.byID {
		journal = store.withStatus(journal)
		if matches(journal, query) {
			items = append(items, journal)
		}
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].OccurredAt.Equal(items[j].OccurredAt) {
			return items[i].ID > items[j].ID
		}
		return items[i].OccurredAt.After(items[j].OccurredAt)
	})
	return items
}

func (store *Memory) List(ctx context.Context, query Query) ([]Journal, error) {
	query, err := NormalizeQuery(query)
	if err != nil {
		return nil, err
	}
	return store.Snapshot(ctx, query, query.Limit+1)
}

func (store *Memory) Snapshot(ctx context.Context, query Query, max int) ([]Journal, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	query, err := NormalizeQuery(query)
	if err != nil || max < 1 || max > MaxExportJournals+1 {
		return nil, ErrInvalidInput
	}
	store.mu.RLock()
	defer store.mu.RUnlock()
	items := store.listLocked(query)
	if len(items) > max {
		items = items[:max]
	}
	return items, nil
}

func (store *Memory) Summary(ctx context.Context, query Query) (Summary, error) {
	if err := ctx.Err(); err != nil {
		return Summary{}, err
	}
	query, err := NormalizeQuery(query)
	if err != nil {
		return Summary{}, err
	}
	query.Before = nil
	store.mu.RLock()
	defer store.mu.RUnlock()
	summary := newSummary(query.Mode)
	for _, journal := range store.byID {
		journal = store.withStatus(journal)
		if matches(journal, query) {
			originalKind := store.byID[journal.ReversalOfID].Kind
			if err := addToSummary(&summary, journal, originalKind); err != nil {
				return Summary{}, err
			}
		}
	}
	return summary, nil
}
