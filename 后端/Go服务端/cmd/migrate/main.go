package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"

	"repair-platform/internal/config"
	"repair-platform/internal/migration"
	"repair-platform/internal/repository"
)

func main() {
	cfg := config.Load()
	resume := flag.String("resume", "", "explicitly resume an inspected dirty migration by filename")
	seedDemo := flag.Bool("seed-demo", cfg.SeedDemoData, "insert demo data without overwriting existing records")
	flag.Parse()
	if cfg.TiDBDSN == "" {
		log.Fatal("set TIDB_DSN before running migrations")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	databaseDSN, err := ensureDatabase(ctx, cfg.TiDBDSN)
	if err != nil {
		log.Fatalf("prepare TiDB database: %v", err)
	}

	tidb, err := repository.OpenTiDB(ctx, databaseDSN)
	if err != nil {
		log.Fatalf("connect to TiDB: %v", err)
	}
	defer tidb.Close()

	if err := migration.Run(ctx, tidb.DB(), os.DirFS("migrations"), *resume); err != nil {
		log.Fatalf("apply migrations: %v", err)
	}
	if *seedDemo {
		if err := migration.Seed(ctx, tidb.DB(), os.DirFS("seeds"), "demo.sql"); err != nil {
			log.Fatalf("seed demo data: %v", err)
		}
	}
	fmt.Println("TiDB schema is ready")
}

// ensureDatabase creates the configured schema before applying table migrations.
func ensureDatabase(ctx context.Context, dsn string) (string, error) {
	driverConfig, err := mysql.ParseDSN(dsn)
	if err != nil {
		return "", err
	}

	databaseName := strings.TrimSpace(driverConfig.DBName)
	if databaseName == "" {
		databaseName = "repair_marketplace"
		driverConfig.DBName = databaseName
	}
	if len(databaseName) > 64 {
		return "", fmt.Errorf("database name exceeds TiDB's 64-character identifier limit")
	}

	bootstrapConfig := *driverConfig
	bootstrapConfig.DBName = ""
	bootstrapStore, err := repository.OpenTiDB(ctx, bootstrapConfig.FormatDSN())
	if err != nil {
		return "", err
	}
	defer bootstrapStore.Close()

	const identifierQuote = "\x60"
	escapedName := strings.ReplaceAll(databaseName, identifierQuote, identifierQuote+identifierQuote)
	if err := bootstrapStore.Exec(ctx, "CREATE DATABASE IF NOT EXISTS "+identifierQuote+escapedName+identifierQuote); err != nil {
		return "", err
	}
	return driverConfig.FormatDSN(), nil
}
