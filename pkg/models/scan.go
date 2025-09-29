package models

import (
	"time"
)

// ScanRequest represents a scan task request
type ScanRequest struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Ports  []int  `json:"ports"`
}

// ScanResult represents the result of scanning a single port
type ScanResult struct {
	ID       string `json:"id"`
	ScanID   string `json:"scan_id"`
	Target   string `json:"target"`
	Port     int    `json:"port"`
	Protocol string `json:"protocol"`
	State    string `json:"state"` // open, closed, filtered
	Error    string `json:"error,omitempty"`
}

// ServiceInfo represents detected service information
type ServiceInfo struct {
	ID          string  `json:"id"`
	ScanID      string  `json:"scan_id"`
	Target      string  `json:"target"`
	Port        int     `json:"port"`
	ServiceName string  `json:"service"`
	Version     string  `json:"version,omitempty"`
	Banner      string  `json:"banner,omitempty"`
	Confidence  float64 `json:"confidence"`
}

// Scan represents a scan session in the database
type Scan struct {
	ID          string    `json:"id"`
	Target      string    `json:"target"`
	Status      string    `json:"status"` // pending, running, completed, failed
	TotalPorts  int       `json:"total_ports"`
	OpenPorts   int       `json:"open_ports"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// Report represents a scan report
type Report struct {
	ScanID    string          `json:"scan_id"`
	Target    string          `json:"target"`
	Timestamp time.Time       `json:"timestamp"`
	Duration  int             `json:"duration_ms"`
	OpenPorts []PortInfo      `json:"open_ports"`
	Stats     ScanStatistics  `json:"statistics"`
}

// PortInfo represents information about an open port
type PortInfo struct {
	Port        int     `json:"port"`
	Protocol    string  `json:"protocol"`
	State       string  `json:"state"`
	ServiceName string  `json:"service,omitempty"`
	Version     string  `json:"version,omitempty"`
	Banner      string  `json:"banner,omitempty"`
	Confidence  float64 `json:"confidence,omitempty"`
}

// ScanStatistics represents scan statistics
type ScanStatistics struct {
	TotalPorts  int `json:"total_ports"`
	OpenPorts   int `json:"open_ports"`
	ClosedPorts int `json:"closed_ports"`
}

// Message represents a NATS message wrapper
type Message struct {
	ID        string      `json:"id"`
	Type      string      `json:"type"`
	Payload   interface{} `json:"payload"`
	Timestamp time.Time   `json:"timestamp"`
}

// Common port list for scanning
var CommonPorts = []int{
	21, 22, 23, 25, 53, 80, 110, 143, 443, 993,
	995, 3306, 3389, 5432, 6379, 8080, 8443, 27017, 3000, 9200,
}