// Created by Jobs on 2026年10月13日，星期二.
package workbench

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const envelopeFormat = "jobs-workbench-aes256gcm-v1"

type envelope struct {
	Format     string    `json:"format"`
	Nonce      string    `json:"nonce"`
	Ciphertext string    `json:"ciphertext"`
	CreatedAt  time.Time `json:"createdAt"`
}

// FilePersistence keeps every business fact and its private attachments at one atomic recovery point.
type FilePersistence struct {
	mu   sync.Mutex
	dir  string
	key  []byte
	lock *os.File
}

func loadKey(path string, create bool) ([]byte, error) {
	key, err := os.ReadFile(path)
	if err == nil {
		if len(key) != 32 {
			return nil, errors.New("存储密钥必须为32字节，拒绝覆盖现有密钥")
		}
		return key, nil
	}
	if !errors.Is(err, os.ErrNotExist) || !create {
		return nil, fmt.Errorf("读取存储密钥失败: %w", err)
	}
	if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, err
	}
	key = make([]byte, 32)
	if _, err = rand.Read(key); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return nil, err
	}
	_, err = file.Write(key)
	if err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		return nil, err
	}
	return key, closeErr
}

func seal(key, raw []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err = rand.Read(nonce); err != nil {
		return nil, err
	}
	sealed := gcm.Seal(nil, nonce, raw, []byte(envelopeFormat))
	return json.Marshal(envelope{Format: envelopeFormat, Nonce: base64.StdEncoding.EncodeToString(nonce), Ciphertext: base64.StdEncoding.EncodeToString(sealed), CreatedAt: time.Now().UTC()})
}

func unseal(key, encrypted []byte) ([]byte, error) {
	var e envelope
	if err := json.Unmarshal(encrypted, &e); err != nil || e.Format != envelopeFormat {
		return nil, errors.New("加密快照格式错误，拒绝明文回退")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce, err := base64.StdEncoding.DecodeString(e.Nonce)
	if err != nil || len(nonce) != gcm.NonceSize() {
		return nil, errors.New("快照 nonce 无效")
	}
	data, err := base64.StdEncoding.DecodeString(e.Ciphertext)
	if err != nil {
		return nil, errors.New("加密快照内容损坏")
	}
	plain, err := gcm.Open(nil, nonce, data, []byte(envelopeFormat))
	if err != nil {
		return nil, errors.New("快照无法解密，密钥不符或内容被修改")
	}
	return plain, nil
}

func atomicWrite(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".snapshot-*")
	if err != nil {
		return err
	}
	tmp := file.Name()
	defer os.Remove(tmp)
	if err = file.Chmod(0600); err == nil {
		_, err = file.Write(data)
	}
	if err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if err = os.Rename(tmp, path); err != nil {
		return err
	}
	// The snapshot is already committed; unsupported directory fsync must not look like a failed write.
	if dir, openErr := os.Open(filepath.Dir(path)); openErr == nil {
		_ = dir.Sync()
		_ = dir.Close()
	}
	return nil
}

func NewFilePersistence(dir, keyFile string) (*FilePersistence, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	_, snapshotErr := os.Stat(filepath.Join(dir, "snapshot.enc"))
	key, err := loadKey(keyFile, errors.Is(snapshotErr, os.ErrNotExist))
	if err != nil {
		return nil, err
	}
	lock, err := os.OpenFile(filepath.Join(dir, "writer.lock"), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return nil, errors.New("数据目录被其他服务占用；异常退出后请先核实进程，再处理 writer.lock")
	}
	_, _ = fmt.Fprintf(lock, "%d\n", os.Getpid())
	return &FilePersistence{dir: dir, key: key, lock: lock}, nil
}

func (p *FilePersistence) Load() ([]byte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	data, err := os.ReadFile(filepath.Join(p.dir, "snapshot.enc"))
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return unseal(p.key, data)
}

func (p *FilePersistence) Save(raw []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !json.Valid(raw) {
		return errors.New("业务快照不是合法JSON")
	}
	data, err := seal(p.key, raw)
	if err != nil {
		return err
	}
	return atomicWrite(filepath.Join(p.dir, "snapshot.enc"), data)
}

func (p *FilePersistence) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.lock == nil {
		return nil
	}
	err := p.lock.Close()
	p.lock = nil
	removeErr := os.Remove(filepath.Join(p.dir, "writer.lock"))
	if err != nil {
		return err
	}
	return removeErr
}

type BackupManifest struct {
	Format    string    `json:"format"`
	CreatedAt time.Time `json:"createdAt"`
	SHA256    string    `json:"sha256"`
	Bytes     int       `json:"bytes"`
	Includes  []string  `json:"includes"`
}

// WriteBackup creates an encrypted portable snapshot; keys are deliberately not copied.
func WriteBackup(p Persistence, keyFile, destination string) (BackupManifest, error) {
	raw, err := p.Load()
	if err != nil {
		return BackupManifest{}, err
	}
	if len(raw) == 0 {
		return BackupManifest{}, errors.New("没有可备份的业务快照")
	}
	key, err := loadKey(keyFile, false)
	if err != nil {
		return BackupManifest{}, err
	}
	data, err := seal(key, raw)
	if err != nil {
		return BackupManifest{}, err
	}
	if _, err = unseal(key, data); err != nil {
		return BackupManifest{}, err
	}
	if _, err = os.Stat(destination); !errors.Is(err, os.ErrNotExist) {
		return BackupManifest{}, errors.New("备份目标已存在或不可访问，拒绝覆盖")
	}
	if err = atomicWrite(destination, data); err != nil {
		return BackupManifest{}, err
	}
	hash := sha256.Sum256(data)
	m := BackupManifest{Format: envelopeFormat, CreatedAt: time.Now().UTC(), SHA256: hex.EncodeToString(hash[:]), Bytes: len(data), Includes: []string{"业务快照", "私有附件和签名", "账号权限", "删除记录", "幂等记录"}}
	manifest, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return BackupManifest{}, err
	}
	if err = atomicWrite(destination+".manifest.json", manifest); err != nil {
		return BackupManifest{}, err
	}
	return m, nil
}

// RestoreBackup always targets a new directory, and merges the newest access/deletion state before exposure.
func RestoreBackup(backupFile, keyFile, currentDataDir, targetDir string) error {
	if currentDataDir == "" || targetDir == "" {
		return errors.New("恢复必须指定当前撤权删除来源和隔离目标")
	}
	sourceAbs, err := filepath.Abs(currentDataDir)
	if err != nil {
		return err
	}
	targetAbs, err := filepath.Abs(targetDir)
	if err != nil {
		return err
	}
	if sourceAbs == targetAbs {
		return errors.New("恢复目标不得覆盖在线数据")
	}
	if _, err = os.Stat(targetAbs); !errors.Is(err, os.ErrNotExist) {
		return errors.New("恢复目标必须为不存在的新目录")
	}
	key, err := loadKey(keyFile, false)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(backupFile)
	if err != nil {
		return err
	}
	manifestRaw, err := os.ReadFile(backupFile + ".manifest.json")
	if err != nil {
		return errors.New("备份清单缺失，拒绝恢复")
	}
	var manifest BackupManifest
	if err = json.Unmarshal(manifestRaw, &manifest); err != nil {
		return err
	}
	hash := sha256.Sum256(data)
	if manifest.Format != envelopeFormat || manifest.SHA256 != hex.EncodeToString(hash[:]) || manifest.Bytes != len(data) {
		return errors.New("备份摘要校验失败")
	}
	raw, err := unseal(key, data)
	if err != nil {
		return err
	}
	latestEncrypted, err := os.ReadFile(filepath.Join(sourceAbs, "snapshot.enc"))
	if err != nil {
		return errors.New("最新撤权删除来源缺失，拒绝恢复")
	}
	latest, err := unseal(key, latestEncrypted)
	if err != nil {
		return err
	}
	merged, err := mergeRestrictions(raw, latest)
	if err != nil {
		return err
	}
	sealed, err := seal(key, merged)
	if err != nil {
		return err
	}
	return atomicWrite(filepath.Join(targetAbs, "snapshot.enc"), sealed)
}

func mergeRestrictions(backup, latest []byte) ([]byte, error) {
	decode := func(data []byte) (map[string]any, error) {
		if !json.Valid(data) {
			return nil, errors.New("恢复约束快照不是合法JSON，拒绝恢复")
		}
		var result map[string]any
		d := json.NewDecoder(bytes.NewReader(data))
		d.UseNumber()
		err := d.Decode(&result)
		if err == nil && result == nil {
			err = errors.New("恢复约束快照必须为对象，拒绝恢复")
		}
		return result, err
	}
	old, err := decode(backup)
	if err != nil {
		return nil, err
	}
	current, err := decode(latest)
	if err != nil {
		return nil, err
	}
	accounts, err := recoveryAccounts(current)
	if err != nil {
		return nil, err
	}
	previousAccounts, err := recoveryAccounts(old)
	if err != nil {
		return nil, err
	}
	currentAccountIDs := map[string]bool{}
	for _, account := range accounts {
		currentAccountIDs[account.Actor.ID] = true
	}
	for _, account := range previousAccounts {
		if !currentAccountIDs[account.Actor.ID] {
			return nil, errors.New("最新账号授权约束不完整，拒绝恢复")
		}
	}
	old["accounts"] = current["accounts"]
	latestOrders, err := recoveryOrderIndex(current, true)
	if err != nil {
		return nil, err
	}
	if err := validateRecoveryOrderAccounts(latestOrders, accounts); err != nil {
		return nil, err
	}
	orders, err := recoveryOrderIndex(old, false)
	if err != nil {
		return nil, err
	}
	type evidenceReference struct{ OrderID, EvidenceID string }
	deleted := map[evidenceReference]map[string]any{}
	currentEvidence := map[evidenceReference]bool{}
	for id, order := range latestOrders {
		if _, exists := order["evidence"]; !exists {
			return nil, fmt.Errorf("工单 %s 的最新证据删除约束缺失，拒绝恢复", id)
		}
		list, err := recoveryEvidence(order)
		if err != nil {
			return nil, err
		}
		for _, e := range list {
			ref := evidenceReference{id, e["id"].(string)}
			currentEvidence[ref] = true
			if e["deleted"] == true {
				deleted[ref] = e
			}
		}
	}
	for id, order := range orders {
		currentOrder, found := latestOrders[id]
		if !found {
			return nil, fmt.Errorf("工单 %s 的最新授权约束缺失，拒绝恢复", id)
		}
		// Restore business history without restoring the people who can access it.
		for _, field := range []string{"customerId", "companyId", "assigneeId", "ownerId"} {
			order[field] = currentOrder[field]
		}
		list, err := recoveryEvidence(order)
		if err != nil {
			return nil, err
		}
		for i, e := range list {
			ref := evidenceReference{id, e["id"].(string)}
			if !currentEvidence[ref] {
				return nil, fmt.Errorf("工单 %s 的最新证据删除约束不完整，拒绝恢复", id)
			}
			if tombstone, found := deleted[ref]; found {
				order["evidence"].([]any)[i] = tombstone
			}
		}
	}
	// Session credentials are process-local; an isolated restart invalidates every old session.
	delete(old, "sessions")
	if err := mergeRecoveryRequests(old, current, accounts); err != nil {
		return nil, err
	}
	restoredAt := time.Now().UTC()
	if err := mergeRecoveryAudit(old, current, restoredAt, len(orders), len(deleted)); err != nil {
		return nil, err
	}
	old["recovery"] = map[string]any{"restoredAt": restoredAt, "restrictionsMerged": true, "orderAuthorizationCount": len(orders), "deletedEvidenceCount": len(deleted)}
	return json.Marshal(old)
}

func recoveryAccounts(state map[string]any) ([]Account, error) {
	list, ok := state["accounts"].([]any)
	if !ok {
		return nil, errors.New("账号授权清单缺失或格式错误，拒绝恢复")
	}
	raw, err := json.Marshal(list)
	if err != nil {
		return nil, err
	}
	var accounts []Account
	if err := json.Unmarshal(raw, &accounts); err != nil {
		return nil, errors.New("账号授权记录结构错误，拒绝恢复")
	}
	if err := validateAccounts(accounts); err != nil {
		return nil, err
	}
	return accounts, nil
}

func validateRecoveryOrderAccounts(orders map[string]map[string]any, accounts []Account) error {
	byID := map[string]Actor{}
	for _, account := range accounts {
		byID[account.Actor.ID] = account.Actor
	}
	for _, order := range orders {
		customer, exists := byID[order["customerId"].(string)]
		if !exists || customer.Role != "customer" || customer.CompanyID != order["companyId"] {
			return errors.New("工单客户或企业授权约束不匹配，拒绝恢复")
		}
		for _, field := range []string{"ownerId", "assigneeId"} {
			id := order[field].(string)
			if id != "" {
				if _, exists := byID[id]; !exists {
					return errors.New("工单负责人或执行人授权来源缺失，拒绝恢复")
				}
			}
		}
	}
	return nil
}

func recoveryRequests(state map[string]any, required bool) (map[string]CachedRequest, error) {
	value, exists := state["idempotency"]
	if !exists && !required {
		return map[string]CachedRequest{}, nil
	}
	list, ok := value.(map[string]any)
	if !ok {
		return nil, errors.New("已消费请求清单缺失或格式错误，拒绝恢复")
	}
	raw, err := json.Marshal(list)
	if err != nil {
		return nil, err
	}
	var requests map[string]CachedRequest
	if err := json.Unmarshal(raw, &requests); err != nil {
		return nil, errors.New("已消费请求记录结构错误，拒绝恢复")
	}
	for key, request := range requests {
		if key == "" || validateCachedRequest(request) != nil {
			return nil, errors.New("已消费请求约束不完整，拒绝恢复")
		}
	}
	return requests, nil
}

func mergeRecoveryRequests(backup, latest map[string]any, accounts []Account) error {
	old, err := recoveryRequests(backup, false)
	if err != nil {
		return err
	}
	current, err := recoveryRequests(latest, true)
	if err != nil {
		return err
	}
	for key, request := range current {
		if previous, exists := old[key]; exists {
			if previous.Hash != request.Hash || previous.Status != request.Status {
				return errors.New("已消费请求摘要或结果状态冲突，拒绝恢复")
			}
			// A previous recovery fence must survive subsequent backups/restores.
			if request.RecoveryState == recoveryReconciliation {
				previous.RecoveryState = recoveryReconciliation
			}
			previous.Body = compactResponse(previous.Body)
			old[key] = previous
			continue
		}
		request.Body = compactResponse(request.Body)
		if request.RecoveryState != recoveryReconciliation && isRecoveryAccountStatusRequest(key, request, accounts) {
			request.RecoveryState = recoveryCurrentAuthorization
		} else {
			// Latest-only business facts rolled back; retaining their keys is not
			// evidence that the old snapshot includes those facts.
			request.RecoveryState = recoveryReconciliation
		}
		old[key] = request
	}
	backup["idempotency"] = old
	return nil
}

func isRecoveryAccountStatusRequest(key string, request CachedRequest, accounts []Account) bool {
	var ref struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(request.Body, &ref) != nil || ref.ID == "" {
		return false
	}
	targetExists := false
	for _, account := range accounts {
		targetExists = targetExists || account.Actor.ID == ref.ID
	}
	if !targetExists {
		return false
	}
	for _, account := range accounts {
		prefix := account.Actor.ID + ":POST /api/v38/accounts/" + ref.ID + "/status:"
		if strings.HasPrefix(key, prefix) && len(key) > len(prefix) {
			return true
		}
	}
	return false
}

func mergeRecoveryAudit(backup, latest map[string]any, at time.Time, orderCount, deletedCount int) error {
	merged := []any{}
	positions := map[string]int{}
	for _, state := range []map[string]any{backup, latest} {
		value, exists := state["audit"]
		if !exists {
			continue
		}
		list, ok := value.([]any)
		if !ok {
			return errors.New("恢复审计清单格式错误，拒绝恢复")
		}
		seen := map[string]bool{}
		for _, item := range list {
			event, ok := item.(map[string]any)
			if !ok {
				return errors.New("恢复审计记录格式错误，拒绝恢复")
			}
			// Earlier anonymous denial events explicitly serialized an empty actor.
			if event["actorId"] == "" && event["actorRole"] == "" && event["result"] == "denied" && (event["type"] == "login" || event["type"] == "authentication") {
				event["actorId"], event["actorRole"] = "anonymous", "anonymous"
			}
			for _, field := range []string{"id", "actorId", "actorRole", "type", "resource", "result", "at"} {
				value, ok := event[field].(string)
				if !ok || strings.TrimSpace(value) == "" {
					return errors.New("恢复审计记录字段缺失或格式错误，拒绝恢复")
				}
			}
			if _, err := time.Parse(time.RFC3339, event["at"].(string)); err != nil {
				return errors.New("恢复审计记录时间格式错误，拒绝恢复")
			}
			for _, field := range []string{"reason", "before", "after"} {
				if value, exists := event[field]; exists {
					if _, ok := value.(string); !ok {
						return errors.New("恢复审计记录字段格式错误，拒绝恢复")
					}
				}
			}
			for _, field := range []string{"authBefore", "authAfter"} {
				if value, exists := event[field]; exists {
					number, ok := value.(json.Number)
					if !ok {
						return errors.New("恢复审计授权版本格式错误，拒绝恢复")
					}
					version, err := number.Int64()
					if err != nil || version < 0 {
						return errors.New("恢复审计授权版本格式错误，拒绝恢复")
					}
				}
			}
			if value, exists := event["resourceIds"]; exists {
				ids, ok := value.([]any)
				if !ok {
					return errors.New("恢复审计资源清单格式错误，拒绝恢复")
				}
				for _, value := range ids {
					if id, ok := value.(string); !ok || strings.TrimSpace(id) == "" {
						return errors.New("恢复审计资源ID格式错误，拒绝恢复")
					}
				}
			}
			id := event["id"].(string)
			if seen[id] {
				return errors.New("恢复审计记录ID重复，拒绝恢复")
			}
			seen[id] = true
			if index, exists := positions[id]; exists {
				merged[index] = event
			} else {
				positions[id] = len(merged)
				merged = append(merged, event)
			}
		}
	}
	merged = append(merged, map[string]any{
		"id": randomID("audit_"), "actorId": "system:restore", "actorRole": "system",
		"type": "backup_restore", "resource": "workbench", "result": "restored", "at": nowString(at),
		"reason": fmt.Sprintf("合并当前工单授权%d条、证据删除约束%d条、审计记录%d条", orderCount, deletedCount, len(merged)),
	})
	backup["audit"] = merged
	return nil
}

func recoveryOrderIndex(state map[string]any, requireAuthorization bool) (map[string]map[string]any, error) {
	list, ok := state["orders"].([]any)
	if !ok {
		return nil, errors.New("工单授权清单缺失或格式错误，拒绝恢复")
	}
	orders := make(map[string]map[string]any, len(list))
	for _, item := range list {
		order, ok := item.(map[string]any)
		if !ok {
			return nil, errors.New("工单授权记录格式错误，拒绝恢复")
		}
		id, ok := order["id"].(string)
		if !ok || strings.TrimSpace(id) == "" {
			return nil, errors.New("工单授权记录缺少稳定ID，拒绝恢复")
		}
		if _, exists := orders[id]; exists {
			return nil, fmt.Errorf("工单 %s 的授权记录重复，拒绝恢复", id)
		}
		if requireAuthorization {
			for _, field := range []string{"customerId", "companyId", "assigneeId", "ownerId"} {
				value, ok := order[field].(string)
				if !ok || ((field == "customerId" || field == "companyId") && strings.TrimSpace(value) == "") {
					return nil, fmt.Errorf("工单 %s 的最新授权字段 %s 缺失或格式错误，拒绝恢复", id, field)
				}
			}
		}
		orders[id] = order
	}
	return orders, nil
}

func recoveryEvidence(order map[string]any) ([]map[string]any, error) {
	if order["evidence"] == nil {
		return nil, nil
	}
	list, ok := order["evidence"].([]any)
	if !ok {
		return nil, errors.New("工单证据删除约束格式错误，拒绝恢复")
	}
	evidence := make([]map[string]any, 0, len(list))
	ids := make(map[string]bool, len(list))
	for _, item := range list {
		e, ok := item.(map[string]any)
		if !ok {
			return nil, errors.New("证据删除约束记录格式错误，拒绝恢复")
		}
		id, ok := e["id"].(string)
		if !ok || strings.TrimSpace(id) == "" || ids[id] {
			return nil, errors.New("证据删除约束ID缺失或重复，拒绝恢复")
		}
		if _, ok := e["deleted"].(bool); !ok {
			return nil, errors.New("证据删除约束标记缺失或格式错误，拒绝恢复")
		}
		ids[id] = true
		evidence = append(evidence, e)
	}
	return evidence, nil
}
