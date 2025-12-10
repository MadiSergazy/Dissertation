-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS service_info (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(255) NOT NULL,
    target VARCHAR(255) NOT NULL,
    port INT NOT NULL,
    service_name VARCHAR(255),
    version VARCHAR(255),
    banner TEXT,
    confidence FLOAT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_service_info_scan_id ON service_info(scan_id);
CREATE INDEX IF NOT EXISTS idx_service_info_port ON service_info(port);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS service_info CASCADE;
-- +goose StatementEnd