ALTER TABLE repair_orders ADD COLUMN IF NOT EXISTS profit_rule_version VARCHAR(64) NOT NULL DEFAULT '';
ALTER TABLE repair_settlements ADD COLUMN IF NOT EXISTS profit_rule_version VARCHAR(64) NOT NULL DEFAULT '';
