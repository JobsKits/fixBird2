// Created by Jobs on 2026年10月13日，星期二.
package workbench

import (
	"context"
	"database/sql"
	"errors"
	"net"
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
	return &TiDBPersistence{db: db, key: key}, nil
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
