-- Journals and entries are append-only through application adapters. No destructive migration of old payments.
CREATE TABLE IF NOT EXISTS repair_ledger_journals (
  id VARCHAR(64) COLLATE utf8mb4_bin PRIMARY KEY,
  event_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  fingerprint CHAR(64) NOT NULL,
  order_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  customer_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  worker_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  settlement_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  mode VARCHAR(16) NOT NULL,
  simulated BOOLEAN NOT NULL,
  kind VARCHAR(32) NOT NULL,
  channel VARCHAR(24) NOT NULL,
  amount_cents BIGINT NOT NULL,
  worker_share_cents BIGINT NOT NULL,
  platform_fee_cents BIGINT NOT NULL,
  actor_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  reason VARCHAR(512) NOT NULL DEFAULT '',
  reversal_of_id VARCHAR(64) COLLATE utf8mb4_bin NULL,
  occurred_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL,
  UNIQUE KEY uq_ledger_event (event_key),
  UNIQUE KEY uq_ledger_reversal (reversal_of_id),
  KEY idx_ledger_mode_time (mode, occurred_at, id),
  KEY idx_ledger_order_time (order_id, occurred_at, id),
  KEY idx_ledger_customer_time (customer_id, occurred_at, id),
  KEY idx_ledger_worker_time (worker_id, occurred_at, id)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS repair_ledger_entries (
  journal_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  line_number INT NOT NULL,
  account VARCHAR(32) NOT NULL,
  direction VARCHAR(8) NOT NULL,
  amount_cents BIGINT NOT NULL,
  PRIMARY KEY (journal_id, line_number),
  KEY idx_ledger_entry_account (account, journal_id)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
