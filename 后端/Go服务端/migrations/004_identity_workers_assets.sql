ALTER TABLE repair_workers ADD COLUMN IF NOT EXISTS qualification_version BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS repair_users (
  id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  username VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  role VARCHAR(16) NOT NULL,
  password_hash VARCHAR(240) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_at TIMESTAMP(3) NOT NULL,
	 session_version BIGINT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_repair_users_username (username)
);

CREATE TABLE IF NOT EXISTS repair_sessions (
	 id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at TIMESTAMP(3) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL,
	 device_kind VARCHAR(16) NOT NULL,
	 device_label VARCHAR(80) NOT NULL,
	 device_platform VARCHAR(40) NOT NULL,
	 auth_method VARCHAR(16) NOT NULL,
	 UNIQUE KEY uq_repair_sessions_id (id),
  KEY idx_repair_sessions_user (user_id),
  KEY idx_repair_sessions_expiry (expires_at)
);

CREATE TABLE IF NOT EXISTS repair_qr_challenges (
  id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  poll_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  approval_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  device_label VARCHAR(80) NOT NULL,
  device_platform VARCHAR(40) NOT NULL,
  status VARCHAR(16) NOT NULL,
  user_id VARCHAR(64) NOT NULL DEFAULT '',
  expires_at TIMESTAMP(3) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL,
  KEY idx_repair_qr_expiry (expires_at)
);

CREATE TABLE IF NOT EXISTS repair_identity_locks (id INT PRIMARY KEY, version BIGINT NOT NULL DEFAULT 0);
INSERT IGNORE INTO repair_identity_locks (id) VALUES (1);

CREATE TABLE IF NOT EXISTS repair_worker_applications (
  id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  worker_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  contact_phone VARCHAR(40) NOT NULL,
  service_areas JSON NOT NULL,
  skills JSON NOT NULL,
  bio TEXT NOT NULL,
  asset_ids JSON NOT NULL,
  status VARCHAR(16) NOT NULL,
  revision BIGINT NOT NULL,
  review_note VARCHAR(1000) NOT NULL DEFAULT '',
  reviewed_by VARCHAR(64) NOT NULL DEFAULT '',
  reviewed_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL,
  updated_at TIMESTAMP(3) NOT NULL,
  UNIQUE KEY uq_worker_application_worker (worker_id),
  KEY idx_worker_application_status_created (status, created_at, id)
);

CREATE TABLE IF NOT EXISTS repair_worker_assets (
  id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  owner_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  mime_type VARCHAR(32) NOT NULL,
  size_bytes BIGINT NOT NULL,
  created_at TIMESTAMP(3) NOT NULL,
  KEY idx_worker_asset_owner_created (owner_id, created_at)
);
