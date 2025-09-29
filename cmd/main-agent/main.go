package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/nats-io/nats.go"
)

type Config struct {
	HTTPPort     string
	DatabaseURL  string
	NATSUrl      string
	MaxRetries   int
	RetryDelay   time.Duration
}

type Server struct {
	config   *Config
	db       *sql.DB
	nc       *nats.Conn
	jsCtx    nats.JetStreamContext
	mu       sync.RWMutex
	shutdown chan struct{}
}

type ScanRequest struct {
	Target string `json:"target"`
	Ports  []int  `json:"ports,omitempty"`
}

type ScanResponse struct {
	ID      string    `json:"id"`
	Target  string    `json:"target"`
	Status  string    `json:"status"`
	Message string    `json:"message,omitempty"`
	Created time.Time `json:"created_at"`
}

type ScanStatus struct {
	ID          string     `json:"id"`
	Target      string     `json:"target"`
	Status      string     `json:"status"`
	TotalPorts  int        `json:"total_ports"`
	OpenPorts   int        `json:"open_ports"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	Results     []PortInfo `json:"results,omitempty"`
}

type PortInfo struct {
	Port        int    `json:"port"`
	State       string `json:"state"`
	ServiceName string `json:"service,omitempty"`
	Version     string `json:"version,omitempty"`
}

type NATSScanRequest struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Ports  []int  `json:"ports"`
}

type NATSScanResult struct {
	ID     string `json:"id"`
	ScanID string `json:"scan_id"`
	Port   int    `json:"port"`
	State  string `json:"state"`
	IsOpen bool   `json:"is_open"`
	Error  string `json:"error,omitempty"`
}

func NewServer(config *Config) (*Server, error) {
	server := &Server{
		config:   config,
		shutdown: make(chan struct{}),
	}

	if err := server.connectDatabase(); err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	if err := server.connectNATS(); err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	return server, nil
}

func (s *Server) connectDatabase() error {
	var err error
	for i := 0; i < s.config.MaxRetries; i++ {
		s.db, err = sql.Open("postgres", s.config.DatabaseURL)
		if err != nil {
			log.Printf("Database connection attempt %d failed: %v", i+1, err)
			time.Sleep(s.config.RetryDelay)
			continue
		}

		if err = s.db.Ping(); err != nil {
			log.Printf("Database ping attempt %d failed: %v", i+1, err)
			time.Sleep(s.config.RetryDelay)
			continue
		}

		log.Println("Successfully connected to PostgreSQL")
		return nil
	}
	return fmt.Errorf("failed to connect to database after %d attempts: %w", s.config.MaxRetries, err)
}

func (s *Server) connectNATS() error {
	var err error
	for i := 0; i < s.config.MaxRetries; i++ {
		s.nc, err = nats.Connect(s.config.NATSUrl,
			nats.MaxReconnects(-1),
			nats.ReconnectWait(time.Second),
			nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
				if err != nil {
					log.Printf("NATS disconnected: %v", err)
				}
			}),
			nats.ReconnectHandler(func(_ *nats.Conn) {
				log.Println("NATS reconnected")
			}),
		)

		if err != nil {
			log.Printf("NATS connection attempt %d failed: %v", i+1, err)
			time.Sleep(s.config.RetryDelay)
			continue
		}

		s.jsCtx, err = s.nc.JetStream()
		if err != nil {
			log.Printf("Failed to create JetStream context: %v", err)
			s.nc.Close()
			time.Sleep(s.config.RetryDelay)
			continue
		}

		if err = s.setupStreams(); err != nil {
			log.Printf("Failed to setup JetStream streams: %v", err)
			s.nc.Close()
			time.Sleep(s.config.RetryDelay)
			continue
		}

		log.Println("Successfully connected to NATS")
		return nil
	}
	return fmt.Errorf("failed to connect to NATS after %d attempts: %w", s.config.MaxRetries, err)
}

func (s *Server) setupStreams() error {
	_, err := s.jsCtx.AddStream(&nats.StreamConfig{
		Name:     "SCAN",
		Subjects: []string{"scan.>"},
		Storage:  nats.FileStorage,
		Replicas: 1,
		MaxAge:   time.Hour * 24,
	})
	if err != nil && !strings.Contains(err.Error(), "already in use") {
		return fmt.Errorf("failed to create SCAN stream: %w", err)
	}
	return nil
}

func (s *Server) handleScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ScanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if req.Target == "" {
		http.Error(w, "Target is required", http.StatusBadRequest)
		return
	}

	if len(req.Ports) == 0 {
		req.Ports = []int{21, 22, 23, 25, 53, 80, 110, 143, 443, 993, 995, 3306, 3389, 5432, 6379, 8080, 8443}
	}

	scanID := uuid.New().String()

	tx, err := s.db.Begin()
	if err != nil {
		log.Printf("Failed to begin transaction: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	_, err = tx.Exec(
		`INSERT INTO scans (id, target, status, total_ports, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, NOW(), NOW())`,
		scanID, req.Target, "pending", len(req.Ports),
	)
	if err != nil {
		log.Printf("Failed to insert scan record: %v", err)
		http.Error(w, "Failed to create scan", http.StatusInternalServerError)
		return
	}

	if err = tx.Commit(); err != nil {
		log.Printf("Failed to commit transaction: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	natsReq := NATSScanRequest{
		ID:     scanID,
		Target: req.Target,
		Ports:  req.Ports,
	}

	data, err := json.Marshal(natsReq)
	if err != nil {
		log.Printf("Failed to marshal NATS request: %v", err)
		s.updateScanStatus(scanID, "failed")
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if _, err = s.jsCtx.Publish("scan.request", data); err != nil {
		log.Printf("Failed to publish scan request: %v", err)
		s.updateScanStatus(scanID, "failed")
		http.Error(w, "Failed to queue scan", http.StatusInternalServerError)
		return
	}

	response := ScanResponse{
		ID:      scanID,
		Target:  req.Target,
		Status:  "pending",
		Message: "Scan queued successfully",
		Created: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Failed to encode response: %v", err)
	}
}

func (s *Server) handleGetScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/scan/")
	if path == "" {
		http.Error(w, "Scan ID is required", http.StatusBadRequest)
		return
	}

	var status ScanStatus
	var completedAt sql.NullTime

	err := s.db.QueryRow(
		`SELECT id, target, status, total_ports, open_ports, created_at, updated_at, completed_at
		 FROM scans WHERE id = $1`,
		path,
	).Scan(&status.ID, &status.Target, &status.Status, &status.TotalPorts,
		&status.OpenPorts, &status.CreatedAt, &status.UpdatedAt, &completedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Scan not found", http.StatusNotFound)
		return
	}

	if err != nil {
		log.Printf("Failed to query scan: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if completedAt.Valid {
		status.CompletedAt = &completedAt.Time
	}

	rows, err := s.db.Query(
		`SELECT sr.port, sr.state, si.service_name, si.version
		 FROM scan_results sr
		 LEFT JOIN service_info si ON sr.scan_id = si.scan_id AND sr.port = si.port
		 WHERE sr.scan_id = $1 AND sr.is_open = true
		 ORDER BY sr.port`,
		path,
	)
	if err != nil {
		log.Printf("Failed to query scan results: %v", err)
	} else {
		defer rows.Close()

		for rows.Next() {
			var info PortInfo
			var serviceName, version sql.NullString

			if err := rows.Scan(&info.Port, &info.State, &serviceName, &version); err != nil {
				log.Printf("Failed to scan row: %v", err)
				continue
			}

			if serviceName.Valid {
				info.ServiceName = serviceName.String
			}
			if version.Valid {
				info.Version = version.String
			}

			status.Results = append(status.Results, info)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(status); err != nil {
		log.Printf("Failed to encode response: %v", err)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	health := struct {
		Status   string `json:"status"`
		Database bool   `json:"database"`
		NATS     bool   `json:"nats"`
	}{
		Status: "healthy",
	}

	if err := s.db.Ping(); err != nil {
		health.Status = "unhealthy"
		health.Database = false
	} else {
		health.Database = true
	}

	if s.nc == nil || !s.nc.IsConnected() {
		health.Status = "unhealthy"
		health.NATS = false
	} else {
		health.NATS = true
	}

	statusCode := http.StatusOK
	if health.Status == "unhealthy" {
		statusCode = http.StatusServiceUnavailable
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(health); err != nil {
		log.Printf("Failed to encode health response: %v", err)
	}
}

func (s *Server) updateScanStatus(scanID, status string) {
	query := `UPDATE scans SET status = $1, updated_at = NOW() WHERE id = $2`
	if _, err := s.db.Exec(query, status, scanID); err != nil {
		log.Printf("Failed to update scan status: %v", err)
	}
}

func (s *Server) listenForResults() {
	subscription, err := s.jsCtx.Subscribe("scan.result", func(msg *nats.Msg) {
		var result NATSScanResult
		if err := json.Unmarshal(msg.Data, &result); err != nil {
			log.Printf("Failed to unmarshal scan result: %v", err)
			msg.Ack()
			return
		}

		tx, err := s.db.Begin()
		if err != nil {
			log.Printf("Failed to begin transaction: %v", err)
			msg.Ack()
			return
		}
		defer tx.Rollback()

		_, err = tx.Exec(
			`INSERT INTO scan_results (scan_id, port, state, is_open, error, created_at)
			 VALUES ($1, $2, $3, $4, $5, NOW())`,
			result.ScanID, result.Port, result.State, result.IsOpen, result.Error,
		)
		if err != nil {
			log.Printf("Failed to insert scan result: %v", err)
			msg.Ack()
			return
		}

		if result.IsOpen {
			_, err = tx.Exec(
				`UPDATE scans SET open_ports = open_ports + 1, updated_at = NOW()
				 WHERE id = $1`,
				result.ScanID,
			)
			if err != nil {
				log.Printf("Failed to update open ports count: %v", err)
			}
		}

		if err = tx.Commit(); err != nil {
			log.Printf("Failed to commit transaction: %v", err)
		}

		msg.Ack()
	}, nats.Durable("main-agent"), nats.ManualAck())

	if err != nil {
		log.Printf("Failed to subscribe to scan results: %v", err)
		return
	}

	log.Println("Started listening for scan results")

	<-s.shutdown
	subscription.Unsubscribe()
}

func (s *Server) setCORSHeaders(handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		handler(w, r)
	}
}

func (s *Server) Start() error {
	go s.listenForResults()

	mux := http.NewServeMux()
	mux.HandleFunc("/scan", s.setCORSHeaders(s.handleScan))
	mux.HandleFunc("/scan/", s.setCORSHeaders(s.handleGetScan))
	mux.HandleFunc("/health", s.setCORSHeaders(s.handleHealth))

	server := &http.Server{
		Addr:         ":" + s.config.HTTPPort,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("Starting HTTP server on port %s", s.config.HTTPPort)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down server...")
	close(s.shutdown)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	if s.nc != nil {
		s.nc.Close()
	}
	if s.db != nil {
		s.db.Close()
	}

	log.Println("Server shutdown complete")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	config := &Config{
		HTTPPort:    getEnv("HTTP_PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/pentool_db?sslmode=disable"),
		NATSUrl:     getEnv("NATS_URL", "nats://localhost:4222"),
		MaxRetries:  5,
		RetryDelay:  2 * time.Second,
	}

	server, err := NewServer(config)
	if err != nil {
		log.Fatalf("Failed to create server: %v", err)
	}

	if err := server.Start(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}