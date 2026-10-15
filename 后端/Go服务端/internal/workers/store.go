package workers

import (
	"context"
	"sort"
	"sync"
	"time"

	"repair-platform/internal/domain"
	"repair-platform/internal/repository"
)

type Store interface {
	GetApplication(context.Context, string) (Application, error)
	Submit(context.Context, Application, int64) (Application, error)
	Review(context.Context, string, ReviewInput, string, time.Time) (Application, error)
	List(context.Context, ListQuery) ([]Application, error)
	SaveAsset(context.Context, Asset) error
	GetAsset(context.Context, string) (Asset, error)
	CanAccept(context.Context, string) (bool, error)
	Ready(context.Context) error
}

type Memory struct {
	mu           sync.RWMutex
	applications map[string]Application
	assets       map[string]Asset
	roster       func(domain.Worker)
}

func NewMemory(roster func(domain.Worker)) *Memory {
	return &Memory{applications: make(map[string]Application), assets: make(map[string]Asset), roster: roster}
}

func cloneApplication(a Application) Application {
	a.ServiceAreas = append([]string{}, a.ServiceAreas...)
	a.Skills = append([]string{}, a.Skills...)
	a.AssetIDs = append([]string{}, a.AssetIDs...)
	if a.ReviewedAt != nil {
		value := *a.ReviewedAt
		a.ReviewedAt = &value
	}
	return a
}

func (r *Memory) Ready(ctx context.Context) error { return ctx.Err() }

func (r *Memory) GetApplication(ctx context.Context, workerID string) (Application, error) {
	if err := ctx.Err(); err != nil {
		return Application{}, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	value, ok := r.applications[workerID]
	if !ok {
		return Application{}, repository.ErrNotFound
	}
	return cloneApplication(value), nil
}

func (r *Memory) Submit(ctx context.Context, input Application, expected int64) (Application, error) {
	if err := ctx.Err(); err != nil {
		return Application{}, err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	current, exists := r.applications[input.WorkerID]
	if (!exists && expected != 0) || (exists && current.Revision != expected) {
		return Application{}, ErrRevisionConflict
	}
	if exists {
		input.ID = current.ID
		input.CreatedAt = current.CreatedAt
	}
	input.Revision = expected + 1
	input.Status = "pending"
	input.ReviewNote = ""
	input.ReviewedBy = ""
	input.ReviewedAt = nil
	r.applications[input.WorkerID] = cloneApplication(input)
	r.updateRoster(input)
	return cloneApplication(input), nil
}

func (r *Memory) updateRoster(a Application) {
	if r.roster != nil {
		r.roster(domain.Worker{ID: a.WorkerID, DisplayName: a.DisplayName, ServiceAreas: a.ServiceAreas, Skills: a.Skills, Status: a.Status})
	}
}

func (r *Memory) Review(ctx context.Context, id string, input ReviewInput, actorID string, now time.Time) (Application, error) {
	if err := ctx.Err(); err != nil {
		return Application{}, err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	for workerID, current := range r.applications {
		if current.ID != id {
			continue
		}
		if current.Revision != input.ExpectedRevision {
			return Application{}, ErrRevisionConflict
		}
		if current.Status != "pending" {
			return Application{}, repository.ErrInvalidState
		}
		current.Status = input.Decision
		current.ReviewNote = input.Note
		current.ReviewedBy = actorID
		current.ReviewedAt = &now
		current.UpdatedAt = now
		r.applications[workerID] = current
		r.updateRoster(current)
		return cloneApplication(current), nil
	}
	return Application{}, repository.ErrNotFound
}

func (r *Memory) List(ctx context.Context, query ListQuery) ([]Application, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	values := make([]Application, 0)
	for _, current := range r.applications {
		if (query.Status == "" || current.Status == query.Status) && domain.BeforeCursor(current.CreatedAt, current.ID, query.Before) {
			values = append(values, cloneApplication(current))
		}
	}
	sort.Slice(values, func(i, j int) bool {
		if values[i].CreatedAt.Equal(values[j].CreatedAt) {
			return values[i].ID > values[j].ID
		}
		return values[i].CreatedAt.After(values[j].CreatedAt)
	})
	if len(values) > query.Limit+1 {
		values = values[:query.Limit+1]
	}
	return values, nil
}

func (r *Memory) SaveAsset(ctx context.Context, value Asset) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, exists := r.assets[value.ID]; exists {
		return repository.ErrAlreadyExists
	}
	r.assets[value.ID] = value
	return nil
}

func (r *Memory) GetAsset(ctx context.Context, id string) (Asset, error) {
	if err := ctx.Err(); err != nil {
		return Asset{}, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	value, ok := r.assets[id]
	if !ok {
		return Asset{}, repository.ErrNotFound
	}
	return value, nil
}

func (r *Memory) CanAccept(ctx context.Context, id string) (bool, error) {
	if err := ctx.Err(); err != nil {
		return false, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	value, exists := r.applications[id]
	if exists {
		return value.Status == "approved", nil
	}
	return id == "worker-demo", nil
}
