package repository

import "repair-platform/internal/domain"

func (r *Memory) EnforceWorkerApproval() { r.enforceWorkerApproval = true }
func (r *TiDB) EnforceWorkerApproval()   { r.enforceWorkerApproval = true }

func (r *Memory) UpsertWorker(worker domain.Worker) {
	r.mu.Lock()
	defer r.mu.Unlock()
	worker.ServiceAreas = append([]string(nil), worker.ServiceAreas...)
	worker.Skills = append([]string(nil), worker.Skills...)
	r.workers[worker.ID] = worker
}
