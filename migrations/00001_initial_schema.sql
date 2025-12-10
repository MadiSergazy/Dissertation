-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS scans (
    id VARCHAR(255) PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    total_ports INT DEFAULT 0,
    open_ports INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scans_status ON scans(status);
CREATE INDEX IF NOT EXISTS idx_scans_created_at ON scans(created_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS scans CASCADE;
-- +goose StatementEnd