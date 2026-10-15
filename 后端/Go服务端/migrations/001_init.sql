CREATE TABLE IF NOT EXISTS repair_workers (
  id VARCHAR(64) PRIMARY KEY,
  display_name VARCHAR(120) NOT NULL,
  service_areas JSON NOT NULL,
  skills JSON NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS repair_orders (
  id VARCHAR(64) PRIMARY KEY,
  customer_id VARCHAR(64) NOT NULL,
  worker_id VARCHAR(64) NOT NULL DEFAULT '',
  category VARCHAR(120) NOT NULL,
  equipment VARCHAR(160) NOT NULL,
  issue TEXT NOT NULL,
  address VARCHAR(500) NOT NULL,
  scheduled_at VARCHAR(100) NOT NULL DEFAULT '',
  status VARCHAR(40) NOT NULL,
  payment_status VARCHAR(40) NOT NULL DEFAULT 'not_started',
  quoted_amount_cents BIGINT NOT NULL DEFAULT 0,
  platform_fee_cents BIGINT NOT NULL DEFAULT 0,
  worker_share_cents BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  KEY idx_repair_orders_customer_created (customer_id, created_at),
  KEY idx_repair_orders_worker_status (worker_id, status),
  KEY idx_repair_orders_status_created (status, created_at)
);

CREATE TABLE IF NOT EXISTS repair_payments (
  id VARCHAR(64) PRIMARY KEY,
  order_id VARCHAR(64) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  amount_cents BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_repair_payments_order (order_id)
);

CREATE TABLE IF NOT EXISTS repair_settlements (
  id VARCHAR(64) PRIMARY KEY,
  order_id VARCHAR(64) NOT NULL,
  worker_id VARCHAR(64) NOT NULL,
  gross_amount_cents BIGINT NOT NULL,
  platform_fee_cents BIGINT NOT NULL,
  worker_share_cents BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_repair_settlements_order (order_id),
  KEY idx_repair_settlements_worker_status (worker_id, status)
);
