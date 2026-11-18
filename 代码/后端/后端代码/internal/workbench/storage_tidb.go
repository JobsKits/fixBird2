// Created by Jobs on 2026年10月13日，星期二.
package workbench

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/go-sql-driver/mysql"
)

type TiDBPersistence struct {
	mu       sync.Mutex
	db       *sql.DB
	key      []byte
	revision int64
	loaded   bool
	mediaDir string
}

func NewTiDBPersistence(dsn, keyFile string, requireTLS bool) (*TiDBPersistence, error) {
	config, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, errors.New("TiDB DSN格式错误")
	}
	host, _, _ := net.SplitHostPort(config.Addr)
	ip := net.ParseIP(host)
	local := config.Net == "unix" || host == "localhost" || (ip != nil && ip.IsLoopback())
	if (!local || requireTLS) && (config.TLSConfig == "" || config.TLSConfig == "false" || config.TLSConfig == "skip-verify" || config.TLSConfig == "preferred") {
		return nil, errors.New("TiDB必须使用验证身份的TLS连接，拒绝明文或跳过验证")
	}
	config.Timeout = 5 * time.Second
	config.ReadTimeout = 10 * time.Second
	config.WriteTimeout = 10 * time.Second
	config.ParseTime = true
	connector, err := mysql.NewConnector(config)
	if err != nil {
		return nil, err
	}
	db := sql.OpenDB(connector)
	db.SetMaxOpenConns(4)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err = db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, errors.New("TiDB连接失败，请检查数据库配置")
	}
	_, err = db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS v38_workbench_snapshot (id BIGINT PRIMARY KEY, revision BIGINT NOT NULL, payload LONGBLOB NOT NULL, updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6))`)
	if err != nil {
		_ = db.Close()
		return nil, err
	}
	var count int
	err = db.QueryRowContext(ctx, "SELECT COUNT(*) FROM v38_workbench_snapshot WHERE id=1").Scan(&count)
	if err != nil {
		_ = db.Close()
		return nil, err
	}
	key, err := loadKey(keyFile, count == 0)
	if err != nil {
		_ = db.Close()
		return nil, err
	}
	return &TiDBPersistence{db: db, key: key, mediaDir: filepath.Join(filepath.Dir(keyFile), "order-media")}, nil
}

func (p *TiDBPersistence) Load() ([]byte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	var encrypted []byte
	var revision int64
	err := p.db.QueryRowContext(ctx, "SELECT revision,payload FROM v38_workbench_snapshot WHERE id=1").Scan(&revision, &encrypted)
	if errors.Is(err, sql.ErrNoRows) {
		if p.loaded && p.revision != 0 {
			return nil, errors.New("数据库快照被外部删除，拒绝继续运行")
		}
		p.revision = 0
		p.loaded = true
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	// Backup reads must never silently advance the writer revision of a stale service aggregate.
	if p.loaded && revision != p.revision {
		return nil, errors.New("数据库已被其他进程更新，请重启重新加载；备份未完成")
	}
	p.revision = revision
	p.loaded = true
	return unseal(p.key, encrypted)
}

func (p *TiDBPersistence) Save(raw []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	encrypted, err := seal(p.key, raw)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	tx, err := p.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var result sql.Result
	if p.revision == 0 {
		result, err = tx.ExecContext(ctx, "INSERT INTO v38_workbench_snapshot(id,revision,payload) VALUES(1,1,?)", encrypted)
	} else {
		result, err = tx.ExecContext(ctx, "UPDATE v38_workbench_snapshot SET revision=revision+1,payload=?,updated_at=CURRENT_TIMESTAMP(6) WHERE id=1 AND revision=?", encrypted, p.revision)
	}
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if n != 1 {
		return errors.New("存储版本冲突，拒绝覆盖其他进程的更新；重启服务重新读取")
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	p.revision++
	return nil
}

func (p *TiDBPersistence) Close() error { return p.db.Close() }

// 备份引用绑定业务内容和随后加载的数据库版本，不能清掉备份完成后的新写入。
func (p *TiDBPersistence) ClearApplicationSnapshotFromBackup(backupFile string) error {
	data, err := os.ReadFile(backupFile)
	if err != nil {
		return err
	}
	manifestRaw, err := os.ReadFile(backupFile + ".manifest.json")
	if err != nil {
		return errors.New("清零引用的备份清单缺失")
	}
	var manifest BackupManifest
	if err = json.Unmarshal(manifestRaw, &manifest); err != nil {
		return errors.New("清零引用的备份清单无效")
	}
	hash := sha256.Sum256(data)
	if manifest.Format != envelopeFormat || manifest.Bytes != len(data) || manifest.Bytes == 0 || manifest.SHA256 != hex.EncodeToString(hash[:]) {
		return errors.New("清零引用的备份摘要校验失败")
	}
	backedUp, err := unseal(p.key, data)
	if err != nil {
		return errors.New("当前密钥不能验证清零引用的备份")
	}
	if err = verifyBackupOrderMedia(backedUp, manifest, backupFile, p.key); err != nil {
		return err
	}
	current, err := p.Load()
	if err != nil {
		return err
	}
	if len(current) != 0 && !bytes.Equal(current, backedUp) {
		return errors.New("数据库含备份之后的新业务数据，拒绝清零；请停止其它写入并重新备份")
	}
	return p.clearApplicationSnapshot(backedUp)
}

// 反部署只撤回本应用聚合记录；行锁与版本条件让并发旧写入失败。
func (p *TiDBPersistence) ClearApplicationSnapshot() error {
	return p.clearApplicationSnapshot(nil)
}

// 带备份引用时在行锁内再次比对，避免同一实例的并发写入越过内容检查。
func (p *TiDBPersistence) clearApplicationSnapshot(backedUp []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	tx, err := p.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var revision int64
	var encrypted []byte
	err = tx.QueryRowContext(ctx, "SELECT revision,payload FROM v38_workbench_snapshot WHERE id=1 FOR UPDATE").Scan(&revision, &encrypted)
	if errors.Is(err, sql.ErrNoRows) {
		return tx.Commit()
	}
	if err != nil {
		return err
	}
	if p.loaded && p.revision != revision {
		return errors.New("数据版本已变化，拒绝清零；请停止其它写入并重新核对")
	}
	raw, err := unseal(p.key, encrypted)
	if err != nil {
		return errors.New("当前密钥不能验证本应用快照，拒绝清零")
	}
	if backedUp != nil && !bytes.Equal(raw, backedUp) {
		return errors.New("数据库含尚未备份的业务数据，拒绝清零")
	}
	result, err := tx.ExecContext(ctx, "DELETE FROM v38_workbench_snapshot WHERE id=1 AND revision=?", revision)
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count != 1 {
		return errors.New("数据版本冲突，未清零应用快照")
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	p.loaded = true
	// 不将版本重置为0；已有持久化实例不能在清零后重新插入旧业务。
	p.revision = revision
	return nil
}
