CREATE TABLE IF NOT EXISTS repair_order_requests (
  actor_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  idempotency_key VARCHAR(128) COLLATE utf8mb4_bin NOT NULL,
  request_hash CHAR(64) NOT NULL,
  order_id VARCHAR(64) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (actor_id, idempotency_key),
  KEY idx_repair_order_requests_order (order_id)
);
