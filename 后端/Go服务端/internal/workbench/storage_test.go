package workbench

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func testRecoveryAccounts(t *testing.T) []Account {
	t.Helper()
	state, err := seedState()
	if err != nil {
		t.Fatal(err)
	}
	return state.Accounts
}

func testRecoveryJSON(t *testing.T, raw string, accounts []Account) []byte {
	t.Helper()
	var state map[string]any
	if err := json.Unmarshal([]byte(raw), &state); err != nil {
		t.Fatal(err)
	}
	state["accounts"] = accounts
	state["idempotency"] = map[string]CachedRequest{}
	data, err := json.Marshal(state)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestEncryptedSnapshotRestartTamperAndExclusiveWriter(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "data")
	keyFile := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = NewFilePersistence(dataDir, keyFile); err == nil {
		t.Fatal("concurrent writer accepted")
	}
	raw := []byte(`{"accounts":[],"orders":[],"secret":"customer-private-note"}`)
	if err = p.Save(raw); err != nil {
		t.Fatal(err)
	}
	encrypted, err := os.ReadFile(filepath.Join(dataDir, "snapshot.enc"))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encrypted, []byte("customer-private-note")) {
		t.Fatal("plaintext leaked")
	}
	if err = p.Close(); err != nil {
		t.Fatal(err)
	}
	p, err = NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	got, err := p.Load()
	if err != nil || !bytes.Equal(got, raw) {
		t.Fatalf("restart: %s %v", got, err)
	}
	wrongKey := bytes.Repeat([]byte{1}, 32)
	if _, err = unseal(wrongKey, encrypted); err == nil {
		t.Fatal("wrong key accepted")
	}
	var e envelope
	if err = json.Unmarshal(encrypted, &e); err != nil {
		t.Fatal(err)
	}
	e.Ciphertext = "AAAA" + e.Ciphertext[4:]
	tampered, _ := json.Marshal(e)
	if _, err = unseal(p.key, tampered); err == nil {
		t.Fatal("tamper accepted")
	}
	if _, err = unseal(p.key, raw); err == nil {
		t.Fatal("plaintext fallback accepted")
	}
}

func TestCompleteBackupRestoreKeepsNewDeletionAndRevocation(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "data")
	keyFile := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(dataDir, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	accounts := testRecoveryAccounts(t)
	before := testRecoveryJSON(t, `{"orders":[{"id":"o","customerId":"customer","companyId":"company-a","assigneeId":"engineer","ownerId":"dispatcher","evidence":[{"id":"e","deleted":false,"data":"cHJpdmF0ZQ=="}],"cash":[{"amountCents":1000}]}]}`, accounts)
	if err = p.Save(before); err != nil {
		t.Fatal(err)
	}
	backup := filepath.Join(dir, "independent", "backup.wbbak")
	manifest, err := WriteBackup(p, keyFile, backup)
	if err != nil || manifest.Bytes == 0 {
		t.Fatalf("backup %v", err)
	}
	if _, err = WriteBackup(p, keyFile, backup); err == nil {
		t.Fatal("backup overwritten")
	}
	accounts[0].Actor.Status = "disabled"
	accounts[0].Actor.AuthVersion++
	after := testRecoveryJSON(t, `{"orders":[{"id":"o","customerId":"customer-peer","companyId":"company-a","assigneeId":"outsource","ownerId":"admin","evidence":[{"id":"e","deleted":true,"data":"","deleteReason":"撤销"}],"cash":[{"amountCents":2000}]}]}`, accounts)
	if err = p.Save(after); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(dir, "isolated")
	if err = RestoreBackup(backup, keyFile, dataDir, target); err != nil {
		t.Fatal(err)
	}
	if err = RestoreBackup(backup, keyFile, dataDir, dataDir); err == nil {
		t.Fatal("online restore accepted")
	}
	restored, err := NewFilePersistence(target, keyFile)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	raw, err := restored.Load()
	if err != nil {
		t.Fatal(err)
	}
	var state struct {
		Accounts []Account `json:"accounts"`
		Orders   []struct {
			Evidence []struct {
				Deleted bool   `json:"deleted"`
				Data    string `json:"data"`
			} `json:"evidence"`
			Cash []struct {
				Amount int64 `json:"amountCents"`
			} `json:"cash"`
		} `json:"orders"`
	}
	if err = json.Unmarshal(raw, &state); err != nil {
		t.Fatal(err)
	}
	if state.Accounts[0].Actor.Status != "disabled" || !state.Orders[0].Evidence[0].Deleted || state.Orders[0].Evidence[0].Data != "" {
		t.Fatal("revoked data resurrected")
	}
	if state.Orders[0].Cash[0].Amount != 1000 {
		t.Fatal("business snapshot not restored to backup point")
	}
	if err = RestoreBackup(backup, keyFile, filepath.Join(dir, "missing"), filepath.Join(dir, "failed")); err == nil {
		t.Fatal("missing restriction source accepted")
	}
}

func TestMissingHistoricalKeyNeverCreatesReplacement(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "data")
	key := filepath.Join(dir, "keys", "storage.key")
	p, err := NewFilePersistence(dataDir, key)
	if err != nil {
		t.Fatal(err)
	}
	if err = p.Save([]byte(`{"orders":[],"accounts":[]}`)); err != nil {
		t.Fatal(err)
	}
	_ = p.Close()
	if err = os.Remove(key); err != nil {
		t.Fatal(err)
	}
	if _, err = NewFilePersistence(dataDir, key); err == nil {
		t.Fatal("missing old key replaced")
	}
	if _, err = os.Stat(key); !os.IsNotExist(err) {
		t.Fatal("new key created")
	}
}
