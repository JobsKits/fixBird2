package config

import (
	"errors"
	"net"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Address                string
	AdminWebDir            string
	WebDir                 string
	TiDBDSN                string
	DemoMode               bool
	AllowDemoNetwork       bool
	SeedDemoData           bool
	WorkerAssetDir         string
	AdminBootstrapUsername string
	AdminBootstrapPassword string
	SessionTTLHours        int
	AllowAnonymousDemo     bool
}

func Load() Config {
	ttl, err := strconv.Atoi(valueOrDefault("SESSION_TTL_HOURS", "24"))
	if err != nil || ttl == 0 {
		ttl = -1
	}
	return Config{
		Address:                valueOrDefault("APP_ADDR", "127.0.0.1:8080"),
		AdminWebDir:            valueOrDefault("ADMIN_WEB_DIR", "../管理后台页面"),
		WebDir:                 valueOrDefault("WEB_DIR", "../../前端/Web网页/旧版用户网页"),
		TiDBDSN:                strings.TrimSpace(os.Getenv("TIDB_DSN")),
		DemoMode:               strings.EqualFold(valueOrDefault("DEMO_MODE", "true"), "true"),
		AllowDemoNetwork:       strings.EqualFold(valueOrDefault("ALLOW_DEMO_NETWORK", "false"), "true"),
		SeedDemoData:           strings.EqualFold(valueOrDefault("SEED_DEMO_DATA", "true"), "true"),
		WorkerAssetDir:         valueOrDefault("WORKER_ASSET_DIR", "./private-uploads"),
		AdminBootstrapUsername: strings.TrimSpace(os.Getenv("ADMIN_BOOTSTRAP_USERNAME")),
		AdminBootstrapPassword: os.Getenv("ADMIN_BOOTSTRAP_PASSWORD"),
		SessionTTLHours:        ttl,
		AllowAnonymousDemo:     strings.EqualFold(valueOrDefault("ALLOW_ANONYMOUS_DEMO", "true"), "true"),
	}
}

func (c Config) Validate() error {
	if !c.DemoMode {
		return errors.New("production mode is disabled until real payment settlement and production infrastructure are implemented")
	}
	if c.SessionTTLHours != 0 && (c.SessionTTLHours < 1 || c.SessionTTLHours > 168) {
		return errors.New("SESSION_TTL_HOURS must be 1..168")
	}
	if (c.AdminBootstrapUsername == "") != (c.AdminBootstrapPassword == "") {
		return errors.New("both ADMIN_BOOTSTRAP_USERNAME and ADMIN_BOOTSTRAP_PASSWORD must be supplied together")
	}
	host, port, err := net.SplitHostPort(c.Address)
	if err != nil {
		return errors.New("APP_ADDR must be host:port")
	}
	number, err := strconv.Atoi(port)
	if err != nil || number < 1 || number > 65535 {
		return errors.New("APP_ADDR port must be 1..65535")
	}
	address := net.ParseIP(host)
	if !c.AllowDemoNetwork && (address == nil || !address.IsLoopback()) && host != "localhost" {
		return errors.New("demo mode requires a loopback IP; container or trusted LAN bindings require ALLOW_DEMO_NETWORK=true")
	}
	return nil
}

func valueOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
