package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"
)

const (
	natsURL      = "nats://localhost:4222"
	scanRequest  = "scan.request"
	scanResult   = "scan.result"
	maxWorkers   = 10
	portTimeout  = 1 * time.Second
)

var topPorts = []int{
	21, 22, 23, 25, 80, 110, 443, 445, 3306, 3389,
	5432, 6379, 8080, 8443, 27017,
}

type ScannerAgent struct {
	nc     *nats.Conn
	logger *logrus.Logger
	ctx    context.Context
	cancel context.CancelFunc
}

type ScanRequest struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Ports  []int  `json:"ports"`
}

type ScanResult struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Port   int    `json:"port"`
	IsOpen bool   `json:"is_open"`
	Error  string `json:"error,omitempty"`
}

func NewScannerAgent() *ScannerAgent {
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)
	logger.SetFormatter(&logrus.JSONFormatter{})

	ctx, cancel := context.WithCancel(context.Background())

	return &ScannerAgent{
		logger: logger,
		ctx:    ctx,
		cancel: cancel,
	}
}

func (sa *ScannerAgent) Connect() error {
	nc, err := nats.Connect(natsURL)
	if err != nil {
		return fmt.Errorf("failed to connect to NATS: %w", err)
	}

	sa.nc = nc
	sa.logger.WithField("url", natsURL).Info("Connected to NATS")
	return nil
}

func (sa *ScannerAgent) Subscribe() error {
	_, err := sa.nc.Subscribe(scanRequest, sa.handleScanRequest)
	if err != nil {
		return fmt.Errorf("failed to subscribe to %s: %w", scanRequest, err)
	}

	sa.logger.WithField("topic", scanRequest).Info("Subscribed to scan requests")
	return nil
}

func (sa *ScannerAgent) handleScanRequest(msg *nats.Msg) {
	var req ScanRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		sa.logger.WithError(err).Error("Failed to unmarshal scan request")
		return
	}

	sa.logger.WithFields(logrus.Fields{
		"id":     req.ID,
		"target": req.Target,
		"ports":  len(req.Ports),
	}).Info("Received scan request")

	// Use default ports if none specified
	ports := req.Ports
	if len(ports) == 0 {
		ports = topPorts
	}

	sa.scanPorts(req.ID, req.Target, ports)
}

func (sa *ScannerAgent) scanPorts(scanID, target string, ports []int) {
	// Channel for collecting results
	results := make(chan ScanResult, len(ports))

	// Worker pool with semaphore
	sem := make(chan struct{}, maxWorkers)
	var wg sync.WaitGroup

	for _, port := range ports {
		wg.Add(1)
		go func(p int) {
			defer wg.Done()

			// Acquire semaphore
			sem <- struct{}{}
			defer func() { <-sem }()

			result := sa.scanPort(scanID, target, p)
			results <- result
		}(port)
	}

	// Close results channel when all workers are done
	go func() {
		wg.Wait()
		close(results)
	}()

	// Publish results as they come in
	for result := range results {
		if err := sa.publishResult(result); err != nil {
			sa.logger.WithError(err).WithFields(logrus.Fields{
				"id":     result.ID,
				"target": result.Target,
				"port":   result.Port,
			}).Error("Failed to publish scan result")
		}
	}

	sa.logger.WithFields(logrus.Fields{
		"id":     scanID,
		"target": target,
		"ports":  len(ports),
	}).Info("Completed port scan")
}

func (sa *ScannerAgent) scanPort(scanID, target string, port int) ScanResult {
	result := ScanResult{
		ID:     scanID,
		Target: target,
		Port:   port,
		IsOpen: false,
	}

	address := fmt.Sprintf("%s:%d", target, port)
	conn, err := net.DialTimeout("tcp", address, portTimeout)

	if err != nil {
		// Port is closed or filtered
		if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
			result.Error = "timeout"
		} else {
			result.Error = "connection_refused"
		}
		sa.logger.WithFields(logrus.Fields{
			"target": target,
			"port":   port,
			"error":  err.Error(),
		}).Debug("Port scan failed")
		return result
	}

	// Port is open
	conn.Close()
	result.IsOpen = true

	sa.logger.WithFields(logrus.Fields{
		"target": target,
		"port":   port,
	}).Info("Found open port")

	return result
}

func (sa *ScannerAgent) publishResult(result ScanResult) error {
	data, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("failed to marshal result: %w", err)
	}

	if err := sa.nc.Publish(scanResult, data); err != nil {
		return fmt.Errorf("failed to publish result: %w", err)
	}

	sa.logger.WithFields(logrus.Fields{
		"id":     result.ID,
		"target": result.Target,
		"port":   result.Port,
		"open":   result.IsOpen,
	}).Debug("Published scan result")

	return nil
}

func (sa *ScannerAgent) Close() {
	if sa.nc != nil {
		sa.nc.Close()
		sa.logger.Info("Closed NATS connection")
	}
	sa.cancel()
}

func (sa *ScannerAgent) Run() error {
	if err := sa.Connect(); err != nil {
		return err
	}

	if err := sa.Subscribe(); err != nil {
		return err
	}

	sa.logger.Info("Scanner Agent started, waiting for scan requests...")

	// Wait for shutdown signal
	<-sa.ctx.Done()
	sa.logger.Info("Scanner Agent shutting down...")
	return nil
}

func main() {
	agent := NewScannerAgent()

	// Setup graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start the agent in a goroutine
	errChan := make(chan error, 1)
	go func() {
		errChan <- agent.Run()
	}()

	// Wait for shutdown signal or error
	select {
	case <-sigChan:
		agent.logger.Info("Received shutdown signal")
		agent.cancel()
		agent.Close()
	case err := <-errChan:
		if err != nil {
			agent.logger.WithError(err).Fatal("Agent failed to run")
		}
	}

	agent.logger.Info("Scanner Agent stopped")
}