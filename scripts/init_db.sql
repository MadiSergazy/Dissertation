-- Database initialization script for pentool
-- Main Agent database schema

-- Create database if not exists (run as superuser)
-- CREATE DATABASE pentool_db;

-- Switch to the pentool database
-- \c pentool_db;

-- Create scans table
CREATE TABLE IF NOT EXISTS scans (
    id VARCHAR(36) PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_ports INTEGER DEFAULT 0,
    open_ports INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP NULL,
    CONSTRAINT status_check CHECK (status IN ('pending', 'running', 'completed', 'failed'))
);

-- Create scan_results table
CREATE TABLE IF NOT EXISTS scan_results (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    port INTEGER NOT NULL,
    protocol VARCHAR(10) DEFAULT 'tcp',
    state VARCHAR(20) NOT NULL,
    is_open BOOLEAN DEFAULT FALSE,
    error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT port_range CHECK (port >= 1 AND port <= 65535),
    CONSTRAINT state_check CHECK (state IN ('open', 'closed', 'filtered'))
);

-- Create service_info table for service detection results
CREATE TABLE IF NOT EXISTS service_info (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    port INTEGER NOT NULL,
    service_name VARCHAR(100),
    version VARCHAR(100),
    banner TEXT,
    confidence DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT port_range CHECK (port >= 1 AND port <= 65535),
    CONSTRAINT confidence_range CHECK (confidence >= 0 AND confidence <= 1)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_scans_status ON scans(status);
CREATE INDEX IF NOT EXISTS idx_scans_target ON scans(target);
CREATE INDEX IF NOT EXISTS idx_scans_created_at ON scans(created_at);
CREATE INDEX IF NOT EXISTS idx_scan_results_scan_id ON scan_results(scan_id);
CREATE INDEX IF NOT EXISTS idx_scan_results_port ON scan_results(port);
CREATE INDEX IF NOT EXISTS idx_scan_results_is_open ON scan_results(is_open);
CREATE INDEX IF NOT EXISTS idx_service_info_scan_id ON service_info(scan_id);
CREATE INDEX IF NOT EXISTS idx_service_info_port ON service_info(port);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_scans_updated_at BEFORE UPDATE ON scans
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create view for scan summaries
CREATE OR REPLACE VIEW scan_summaries AS
SELECT
    s.id,
    s.target,
    s.status,
    s.total_ports,
    s.open_ports,
    s.created_at,
    s.updated_at,
    s.completed_at,
    COUNT(DISTINCT sr.port) as scanned_ports,
    COUNT(DISTINCT CASE WHEN sr.is_open THEN sr.port END) as confirmed_open_ports,
    CASE
        WHEN s.completed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (s.completed_at - s.created_at)) * 1000
        ELSE NULL
    END as duration_ms
FROM scans s
LEFT JOIN scan_results sr ON s.id = sr.scan_id
GROUP BY s.id, s.target, s.status, s.total_ports, s.open_ports,
         s.created_at, s.updated_at, s.completed_at;

-- Sample query to get recent scans with results
-- SELECT
--     s.*,
--     array_agg(
--         json_build_object(
--             'port', sr.port,
--             'state', sr.state,
--             'service', si.service_name,
--             'version', si.version
--         ) ORDER BY sr.port
--     ) FILTER (WHERE sr.is_open) as open_ports_detail
-- FROM scans s
-- LEFT JOIN scan_results sr ON s.id = sr.scan_id AND sr.is_open = true
-- LEFT JOIN service_info si ON s.id = si.scan_id AND sr.port = si.port
-- WHERE s.created_at >= NOW() - INTERVAL '24 hours'
-- GROUP BY s.id
-- ORDER BY s.created_at DESC;