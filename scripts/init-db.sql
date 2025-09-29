-- Create database schema for pentool
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Scans table
CREATE TABLE IF NOT EXISTS scans (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    target VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    total_ports INT DEFAULT 0,
    open_ports INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- Scan results table
CREATE TABLE IF NOT EXISTS scan_results (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    port INTEGER NOT NULL,
    protocol VARCHAR(10) DEFAULT 'tcp',
    state VARCHAR(20) DEFAULT 'unknown' CHECK (state IN ('open', 'closed', 'filtered', 'unknown')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Services table
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    port INTEGER NOT NULL,
    service_name VARCHAR(100),
    version VARCHAR(100),
    banner TEXT,
    confidence DECIMAL(3,2) DEFAULT 0.00,
    detected_at TIMESTAMP DEFAULT NOW()
);

-- Reports table
CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    report_type VARCHAR(20) DEFAULT 'json' CHECK (report_type IN ('json', 'xml', 'csv', 'html')),
    report_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scans_status ON scans(status);
CREATE INDEX IF NOT EXISTS idx_scans_target ON scans(target);
CREATE INDEX IF NOT EXISTS idx_scan_results_scan_id ON scan_results(scan_id);
CREATE INDEX IF NOT EXISTS idx_scan_results_port ON scan_results(port);
CREATE INDEX IF NOT EXISTS idx_services_scan_id ON services(scan_id);
CREATE INDEX IF NOT EXISTS idx_reports_scan_id ON reports(scan_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for scans table
DROP TRIGGER IF EXISTS update_scans_updated_at ON scans;
CREATE TRIGGER update_scans_updated_at BEFORE UPDATE ON scans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();