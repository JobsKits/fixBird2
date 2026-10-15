// Created by Jobs on 2026年10月13日，星期二.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"repair-platform/internal/workbench"
)

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func main() {
	if err := run(); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}

func run() error {
	backup := flag.String("backup", "", "写入新的独立加密备份文件，不包括密钥")
	restore := flag.String("restore", "", "读取加密备份，必须同时提供 -restore-target 新目录")
	restoreTarget := flag.String("restore-target", "", "全新的隔离恢复目录，禁止覆盖现有目录")
	flag.Parse()
	dataDir := env("WB_DATA_DIR", "../../.runtime/data")
	keyFile := env("WB_KEY_FILE", filepath.Join(filepath.Dir(dataDir), "keys", "storage.key"))
	if *restore != "" {
		if env("WB_TIDB_DSN", "") != "" {
			return errors.New("TiDB恢复需独立数据库演练；此命令只支持本地加密快照隔离恢复")
		}
		if err := workbench.RestoreBackup(*restore, keyFile, dataDir, *restoreTarget); err != nil {
			return err
		}
		log.Print("隔离恢复完成；已合并最新账号及工单授权、证据删除与审计记录，旧会话不会复用")
		return nil
	}
	var p interface {
		workbench.Persistence
		Close() error
	}
	var err error
	if dsn := env("WB_TIDB_DSN", ""); dsn != "" {
		p, err = workbench.NewTiDBPersistence(dsn, keyFile, env("WB_REQUIRE_DB_TLS", "false") == "true")
	} else {
		p, err = workbench.NewFilePersistence(dataDir, keyFile)
	}
	if err != nil {
		return err
	}
	defer p.Close()
	if *backup != "" {
		_, err = workbench.WriteBackup(p, keyFile, *backup)
		if err != nil {
			return err
		}
		log.Print("完整加密备份与摘要清单已写入；密钥须另行安全保管")
		return nil
	}
	address := env("WB_ADDR", "127.0.0.1:8098")
	host, _, err := net.SplitHostPort(address)
	ip := net.ParseIP(host)
	if err != nil || (host != "localhost" && (ip == nil || !ip.IsLoopback())) {
		return errors.New("V3.8合成演示仅允许回环地址，真实内测须另行验证可信HTTPS与运维配置")
	}
	svc, err := workbench.New(p)
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()
		for {
			if taskErr := svc.RunScheduledTasks(ctx); taskErr != nil && ctx.Err() == nil {
				log.Print("自动验收扫描失败，请核对存储与待办")
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
	monitor := &backupMonitor{Configured: env("WB_BACKUP_DIR", "") != ""}
	if monitor.Configured {
		minutes, parseErr := strconv.Atoi(env("WB_BACKUP_INTERVAL_MINUTES", "1440"))
		if parseErr != nil || minutes < 1 {
			return errors.New("WB_BACKUP_INTERVAL_MINUTES必须是正整数")
		}
		go monitor.run(ctx, p, keyFile, env("WB_BACKUP_DIR", ""), time.Duration(minutes)*time.Minute)
	}
	business := svc.Handler(env("WB_WEB_DIR", "../../前端/Web网页/维修工作台"))
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet && r.URL.Path == "/securityz" {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Cache-Control", "no-store")
			monitor.mu.Lock()
			defer monitor.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{"demoOnly": true, "configured": monitor.Configured, "lastAttempt": monitor.LastAttempt, "lastSuccess": monitor.LastSuccess, "error": monitor.Error, "storage": map[bool]string{true: "TiDB encrypted snapshot", false: "local encrypted snapshot"}[env("WB_TIDB_DSN", "") != ""]})
			return
		}
		business.ServeHTTP(w, r)
	})
	server := &http.Server{Addr: address, Handler: handler, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 30 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second}
	go func() {
		<-ctx.Done()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(ctx)
	}()
	log.Printf("啄木鸟维修 V3.8 · 合成演示 · http://%s/", address)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

type backupMonitor struct {
	mu          sync.Mutex
	Configured  bool
	LastAttempt time.Time
	LastSuccess time.Time
	Error       string
}

func (m *backupMonitor) run(ctx context.Context, p workbench.Persistence, keyFile, dir string, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		now := time.Now().UTC()
		m.mu.Lock()
		m.LastAttempt = now
		m.mu.Unlock()
		manifest, err := workbench.WriteBackup(p, keyFile, filepath.Join(dir, fmt.Sprintf("workbench-%s.wbbak", now.Format("20060102T150405.000000000Z"))))
		m.mu.Lock()
		if err != nil {
			m.Error = "备份失败，请检查独立目标和密钥"
			log.Print(m.Error)
		} else {
			m.Error = ""
			m.LastSuccess = manifest.CreatedAt
		}
		m.mu.Unlock()
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}
