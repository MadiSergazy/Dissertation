-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS scan_results (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(255) NOT NULL,
    port INT NOT NULL,
    protocol VARCHAR(10) DEFAULT 'tcp',
    state VARCHAR(20) DEFAULT 'unknown',
    is_open BOOLEAN DEFAULT false,
    error VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_scan_results_scan_id ON scan_results(scan_id);
CREATE INDEX IF NOT EXISTS idx_scan_results_port ON scan_results(port);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS scan_results CASCADE;
-- +goose StatementEnd