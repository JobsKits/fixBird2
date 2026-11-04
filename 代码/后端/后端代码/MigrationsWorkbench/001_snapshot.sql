-- Jobs V3.8 standalone workbench: an encrypted aggregate snapshot, isolated from legacy tables.
-- The application creates this table additively; existing legacy work orders are never remapped.
CREATE TABLE IF NOT EXISTS v38_workbench_snapshot (
    id BIGINT PRIMARY KEY,
    revision BIGINT NOT NULL,
    payload LONGBLOB NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);
