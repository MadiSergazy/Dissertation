package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/lib/pq"
	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"

	"github.com/pentool/pentool/pkg/models"
)

const (
	resultTimeout    = 30 * time.Second
	maxResultsWait   = 20
	natsURL         = "nats://localhost:4222"
	postgresConnStr = "postgres://admin:password@localhost/pentool?sslmode=disable"
)

type ReporterAgent struct {
	nc              *nats.Conn
	db              *sql.DB
	log             *logrus.Logger
	scanAggregators map[string]*ScanAggregator
	mutex           sync.RWMutex
}

type ScanAggregator struct {
	scanID      string
	target      string
	results     []models.ScanResult
	services    []models.ServiceInfo
	startTime   time.Time
	timer       *time.Timer
	resultCount int
	mutex       sync.Mutex
}

type Report struct {
	ScanID     string                `json:"scan_id"`
	Target     string                `json:"target"`
	Timestamp  time.Time             `json:"timestamp"`
	DurationMs int64                 `json:"duration_ms"`
	OpenPorts  []OpenPortInfo        `json:"open_ports"`
	Statistics models.ScanStatistics `json:"statistics"`
}

type OpenPortInfo struct {
	Port    int    `json:"port"`
	Service string `json:"service,omitempty"`
	Version string `json:"version,omitempty"`
}

func NewReporterAgent() (*ReporterAgent, error) {
	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})
	logger.SetLevel(logrus.InfoLevel)

	// Connect to NATS
	nc, err := nats.Connect(natsURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}
	logger.Info("Connected to NATS")

	// Connect to PostgreSQL
	db, err := sql.Open("postgres", postgresConnStr)
	if err != nil {
		nc.Close()
		return nil, fmt.Errorf("failed to connect to PostgreSQL: %w", err)
	}

	if err := db.Ping(); err != nil {
		nc.Close()
		db.Close()
		return nil, fmt.Errorf("failed to ping PostgreSQL: %w", err)
	}
	logger.Info("Connected to PostgreSQL")

	// Create reports table if not exists
	if err := createReportsTable(db); err != nil {
		nc.Close()
		db.Close()
		return nil, fmt.Errorf("failed to create reports table: %w", err)
	}

	return &ReporterAgent{
		nc:              nc,
		db:              db,
		log:             logger,
		scanAggregators: make(map[string]*ScanAggregator),
	}, nil
}

func createReportsTable(db *sql.DB) error {
	query := `
	CREATE TABLE IF NOT EXISTS reports (
		id SERIAL PRIMARY KEY,
		scan_id VARCHAR(36) NOT NULL,
		report JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT NOW()
	);

	CREATE INDEX IF NOT EXISTS idx_reports_scan_id ON reports(scan_id);`

	_, err := db.Exec(query)
	return err
}

func (ra *ReporterAgent) Start(ctx context.Context) error {
	// Subscribe to scan.result topic
	resultSub, err := ra.nc.Subscribe("scan.result", ra.handleScanResult)
	if err != nil {
		return fmt.Errorf("failed to subscribe to scan.result: %w", err)
	}
	ra.log.Info("Subscribed to scan.result")

	// Subscribe to service.detected topic
	serviceSub, err := ra.nc.Subscribe("service.detected", ra.handleServiceDetected)
	if err != nil {
		resultSub.Unsubscribe()
		return fmt.Errorf("failed to subscribe to service.detected: %w", err)
	}
	ra.log.Info("Subscribed to service.detected")

	<-ctx.Done()

	// Cleanup
	resultSub.Unsubscribe()
	serviceSub.Unsubscribe()

	// Generate reports for any remaining scans
	ra.mutex.Lock()
	for scanID, aggregator := range ra.scanAggregators {
		aggregator.timer.Stop()
		ra.generateReport(aggregator)
		ra.log.WithField("scan_id", scanID).Info("Generated final report on shutdown")
	}
	ra.mutex.Unlock()

	return nil
}

func (ra *ReporterAgent) handleScanResult(msg *nats.Msg) {
	var result models.ScanResult
	if err := json.Unmarshal(msg.Data, &result); err != nil {
		ra.log.WithError(err).Error("Failed to unmarshal scan result")
		return
	}

	ra.log.WithFields(logrus.Fields{
		"scan_id": result.ScanID,
		"port":    result.Port,
		"state":   result.State,
	}).Debug("Received scan result")

	ra.mutex.Lock()
	aggregator, exists := ra.scanAggregators[result.ScanID]
	if !exists {
		aggregator = &ScanAggregator{
			scanID:    result.ScanID,
			target:    result.Target,
			results:   make([]models.ScanResult, 0),
			services:  make([]models.ServiceInfo, 0),
			startTime: time.Now(),
		}

		// Set timeout for report generation
		aggregator.timer = time.AfterFunc(resultTimeout, func() {
			ra.mutex.Lock()
			if agg, ok := ra.scanAggregators[result.ScanID]; ok {
				delete(ra.scanAggregators, result.ScanID)
				ra.mutex.Unlock()
				ra.generateReport(agg)
			} else {
				ra.mutex.Unlock()
			}
		})

		ra.scanAggregators[result.ScanID] = aggregator
	}
	ra.mutex.Unlock()

	// Add result to aggregator
	aggregator.mutex.Lock()
	aggregator.results = append(aggregator.results, result)
	aggregator.resultCount++
	count := aggregator.resultCount
	aggregator.mutex.Unlock()

	// Check if we've reached max results
	if count >= maxResultsWait {
		ra.mutex.Lock()
		if agg, ok := ra.scanAggregators[result.ScanID]; ok {
			agg.timer.Stop()
			delete(ra.scanAggregators, result.ScanID)
			ra.mutex.Unlock()
			ra.generateReport(agg)
		} else {
			ra.mutex.Unlock()
		}
	}
}

func (ra *ReporterAgent) handleServiceDetected(msg *nats.Msg) {
	var service models.ServiceInfo
	if err := json.Unmarshal(msg.Data, &service); err != nil {
		ra.log.WithError(err).Error("Failed to unmarshal service info")
		return
	}

	ra.log.WithFields(logrus.Fields{
		"scan_id": service.ScanID,
		"port":    service.Port,
		"service": service.ServiceName,
	}).Debug("Received service info")

	ra.mutex.RLock()
	aggregator, exists := ra.scanAggregators[service.ScanID]
	ra.mutex.RUnlock()

	if exists {
		aggregator.mutex.Lock()
		aggregator.services = append(aggregator.services, service)
		aggregator.mutex.Unlock()
	}
}

func (ra *ReporterAgent) generateReport(aggregator *ScanAggregator) {
	aggregator.mutex.Lock()
	defer aggregator.mutex.Unlock()

	duration := time.Since(aggregator.startTime).Milliseconds()

	// Build open ports list
	openPorts := make([]OpenPortInfo, 0)
	serviceMap := make(map[int]models.ServiceInfo)

	// Create service map for quick lookup
	for _, service := range aggregator.services {
		serviceMap[service.Port] = service
	}

	// Count statistics
	var openCount, closedCount int
	for _, result := range aggregator.results {
		if result.State == "open" {
			openCount++
			portInfo := OpenPortInfo{
				Port: result.Port,
			}

			// Add service info if available
			if service, ok := serviceMap[result.Port]; ok {
				portInfo.Service = service.ServiceName
				portInfo.Version = service.Version
			}

			openPorts = append(openPorts, portInfo)
		} else if result.State == "closed" {
			closedCount++
		}
	}

	// Create report
	report := Report{
		ScanID:     aggregator.scanID,
		Target:     aggregator.target,
		Timestamp:  time.Now(),
		DurationMs: duration,
		OpenPorts:  openPorts,
		Statistics: models.ScanStatistics{
			TotalPorts:  len(aggregator.results),
			OpenPorts:   openCount,
			ClosedPorts: closedCount,
		},
	}

	// Convert report to JSON
	reportJSON, err := json.Marshal(report)
	if err != nil {
		ra.log.WithError(err).Error("Failed to marshal report")
		return
	}

	// Save report to database
	if err := ra.saveReport(aggregator.scanID, reportJSON); err != nil {
		ra.log.WithError(err).Error("Failed to save report")
		return
	}

	// Update scan status to completed
	if err := ra.updateScanStatus(aggregator.scanID, "completed"); err != nil {
		ra.log.WithError(err).Error("Failed to update scan status")
		return
	}

	ra.log.WithFields(logrus.Fields{
		"scan_id":     aggregator.scanID,
		"target":      aggregator.target,
		"duration_ms": duration,
		"open_ports":  openCount,
		"total_ports": len(aggregator.results),
	}).Info("Report generated successfully")
}

func (ra *ReporterAgent) saveReport(scanID string, reportJSON []byte) error {
	query := `INSERT INTO reports (scan_id, report) VALUES ($1, $2)`
	_, err := ra.db.Exec(query, scanID, reportJSON)
	return err
}

func (ra *ReporterAgent) updateScanStatus(scanID string, status string) error {
	query := `UPDATE scans SET status = $1, updated_at = NOW(), completed_at = NOW() WHERE id = $2`
	_, err := ra.db.Exec(query, status, scanID)
	if err != nil {
		// If scans table doesn't exist yet, log but don't fail
		if pqErr, ok := err.(*pq.Error); ok && pqErr.Code == "42P01" {
			ra.log.WithField("scan_id", scanID).Warn("Scans table doesn't exist yet, skipping status update")
			return nil
		}
	}
	return err
}

func (ra *ReporterAgent) Close() {
	ra.nc.Close()
	ra.db.Close()
}

func main() {
	agent, err := NewReporterAgent()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to create reporter agent")
	}
	defer agent.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigChan
		agent.log.Info("Shutting down reporter agent...")
		cancel()
	}()

	agent.log.Info("Reporter agent started")
	if err := agent.Start(ctx); err != nil {
		agent.log.WithError(err).Fatal("Reporter agent failed")
	}

	agent.log.Info("Reporter agent stopped")
}