package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"repair-platform/internal/config"
	"repair-platform/internal/httpapi"
	"repair-platform/internal/identity"
	"repair-platform/internal/ledger"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"repair-platform/internal/workers"
)

func main() {
	cfg := config.Load()
	if err := cfg.Validate(); err != nil {
		log.Fatal(err)
	}

	var store repository.Repository = repository.NewMemory()
	memory := store.(*repository.Memory)
	var accountStore identity.Store = identity.NewMemory()
	var workerStore workers.Store = workers.NewMemory(memory.UpsertWorker)
	var ledgerStore ledger.Store = memory.LedgerStore()
	memory.EnforceWorkerApproval()
	var closeStore func() error
	if cfg.TiDBDSN != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		tidb, err := repository.OpenTiDB(ctx, cfg.TiDBDSN)
		cancel()
		if err != nil {
			log.Fatalf("connect to TiDB: %v", err)
		}
		store = tidb
		tidb.EnforceWorkerApproval()
		accountStore = identity.NewTiDB(tidb.DB())
		workerStore = workers.NewTiDB(tidb.DB())
		ledgerStore = tidb.LedgerStore()
		backfillCtx, backfillCancel := context.WithTimeout(context.Background(), 30*time.Second)
		err = ledgerStore.(*ledger.TiDB).Backfill(backfillCtx)
		backfillCancel()
		if err != nil {
			_ = tidb.Close()
			log.Fatal("initialize simulated ledger: check migration and existing demo data consistency")
		}
		closeStore = tidb.Close
		log.Println("repository: TiDB")
	} else {
		log.Println("repository: memory demo; orders are not persistent")
	}
	if closeStore != nil {
		defer closeStore()
	}

	marketplace := service.NewMarketplace(store, cfg.DemoMode)
	onboarding, err := workers.NewService(workerStore, cfg.WorkerAssetDir)
	if err != nil {
		log.Fatalf("initialize private worker assets: %v", err)
	}
	accounts, err := identity.NewService(accountStore, time.Duration(cfg.SessionTTLHours)*time.Hour)
	if err != nil {
		log.Fatalf("initialize accounts: %v", err)
	}
	bootstrapCtx, bootstrapCancel := context.WithTimeout(context.Background(), 10*time.Second)
	err = accounts.BootstrapAdmin(bootstrapCtx, "", "")
	if err == nil && cfg.AdminBootstrapUsername != "" {
		err = accounts.BootstrapAdmin(bootstrapCtx, cfg.AdminBootstrapUsername, cfg.AdminBootstrapPassword)
	}
	bootstrapCancel()
	if err != nil {
		log.Fatal("initialize administrator: check bootstrap configuration and schema")
	}
	marketplace.SetWorkerGate(onboarding)
	api := httpapi.New(marketplace, cfg.AdminWebDir)
	api.SetWebDir(cfg.WebDir)
	api.EnableIdentity(accounts, onboarding, cfg.AllowAnonymousDemo)
	api.SetLedger(ledger.NewService(ledgerStore))
	server := &http.Server{
		Addr:              cfg.Address,
		Handler:           api.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      12 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	log.Printf("repair API listening on http://%s", cfg.Address)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
