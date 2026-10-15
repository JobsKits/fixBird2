package workbench

import (
	"context"
	"encoding/json"
)

// SweepAutoAcceptance commits the same checked facts used by the manual scan.
func (s *Service) SweepAutoAcceptance() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := json.Marshal(s.state)
	if err != nil {
		return err
	}
	var next State
	if err = json.Unmarshal(data, &next); err != nil {
		return err
	}
	result, err := s.autoAccept(&next, Actor{ID: "system", Name: "后台验收任务", Role: "admin"})
	if err != nil {
		return err
	}
	if len(result["accepted"].([]string)) == 0 {
		return nil
	}
	if err = validateState(next); err != nil {
		return err
	}
	data, err = json.Marshal(next)
	if err != nil {
		return err
	}
	if err = s.persistence.Save(data); err != nil {
		return err
	}
	s.state = next
	return nil
}

func (s *Service) RunScheduledTasks(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	return s.SweepAutoAcceptance()
}
