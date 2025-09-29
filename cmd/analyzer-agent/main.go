package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

type ScanResult struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Port   int    `json:"port"`
	IsOpen bool   `json:"is_open"`
	Error  string `json:"error,omitempty"`
}

type ServiceInfo struct {
	ScanID  string `json:"scan_id"`
	Target  string `json:"target"`
	Port    int    `json:"port"`
	Service string `json:"service"`
	Version string `json:"version,omitempty"`
	Banner  string `json:"banner,omitempty"`
}

type ServiceDetector struct {
	nc              *nats.Conn
	serviceRegistry map[int]string
	wg              sync.WaitGroup
	ctx             context.Context
	cancel          context.CancelFunc
}

func NewServiceDetector() *ServiceDetector {
	ctx, cancel := context.WithCancel(context.Background())
	return &ServiceDetector{
		ctx:    ctx,
		cancel: cancel,
		serviceRegistry: map[int]string{
			21:    "FTP",
			22:    "SSH",
			23:    "Telnet",
			25:    "SMTP",
			80:    "HTTP",
			110:   "POP3",
			143:   "IMAP",
			443:   "HTTPS",
			445:   "SMB",
			1433:  "MSSQL",
			3306:  "MySQL",
			3389:  "RDP",
			5432:  "PostgreSQL",
			5900:  "VNC",
			6379:  "Redis",
			8080:  "HTTP-Proxy",
			8443:  "HTTPS-Alt",
			27017: "MongoDB",
		},
	}
}

func (sd *ServiceDetector) Connect() error {
	natsURL := os.Getenv("NATS_URL")
	if natsURL == "" {
		natsURL = "nats://localhost:4222"
	}

	log.WithField("url", natsURL).Info("Connecting to NATS")

	nc, err := nats.Connect(natsURL,
		nats.ReconnectWait(time.Second*2),
		nats.MaxReconnects(10),
		nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
			if err != nil {
				log.WithError(err).Warn("Disconnected from NATS")
			}
		}),
		nats.ReconnectHandler(func(nc *nats.Conn) {
			log.Info("Reconnected to NATS")
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to NATS: %w", err)
	}

	sd.nc = nc
	log.Info("Successfully connected to NATS")
	return nil
}

func (sd *ServiceDetector) Subscribe() error {
	_, err := sd.nc.Subscribe("scan.result", func(msg *nats.Msg) {
		var result ScanResult
		if err := json.Unmarshal(msg.Data, &result); err != nil {
			log.WithError(err).Error("Failed to unmarshal scan result")
			return
		}

		if result.IsOpen {
			sd.wg.Add(1)
			go func() {
				defer sd.wg.Done()
				sd.detectService(result)
			}()
		}
	})

	if err != nil {
		return fmt.Errorf("failed to subscribe to scan.result: %w", err)
	}

	log.Info("Subscribed to scan.result topic")
	return nil
}

func (sd *ServiceDetector) detectService(result ScanResult) {
	log.WithFields(logrus.Fields{
		"target": result.Target,
		"port":   result.Port,
	}).Debug("Detecting service")

	serviceInfo := ServiceInfo{
		ScanID: result.ID,
		Target: result.Target,
		Port:   result.Port,
	}

	// First try to identify by port number
	if service, ok := sd.serviceRegistry[result.Port]; ok {
		serviceInfo.Service = service
	}

	// Then try specific detection methods
	switch result.Port {
	case 22:
		sd.detectSSH(&serviceInfo)
	case 80, 8080:
		sd.detectHTTP(&serviceInfo)
	case 443, 8443:
		sd.detectHTTPS(&serviceInfo)
	case 3306:
		sd.detectMySQL(&serviceInfo)
	case 5432:
		sd.detectPostgreSQL(&serviceInfo)
	case 6379:
		sd.detectRedis(&serviceInfo)
	case 27017:
		sd.detectMongoDB(&serviceInfo)
	default:
		// Generic banner grabbing
		sd.grabBanner(&serviceInfo)
	}

	// Publish the result
	sd.publishServiceInfo(serviceInfo)
}

func (sd *ServiceDetector) detectSSH(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for SSH detection")
		return
	}
	defer conn.Close()

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	reader := bufio.NewReader(conn)
	banner, err := reader.ReadString('\n')
	if err != nil && err != io.EOF {
		log.WithError(err).Debug("Failed to read SSH banner")
		return
	}

	info.Banner = strings.TrimSpace(banner)
	if strings.Contains(banner, "SSH") {
		info.Service = "SSH"
		// Extract version if possible
		if strings.Contains(banner, "OpenSSH") {
			parts := strings.Split(banner, " ")
			if len(parts) > 1 {
				info.Version = parts[1]
			}
		}
	}
}

func (sd *ServiceDetector) detectHTTP(info *ServiceInfo) {
	client := &http.Client{
		Timeout: 2 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	url := fmt.Sprintf("http://%s:%d/", info.Target, info.Port)
	resp, err := client.Get(url)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for HTTP detection")
		return
	}
	defer resp.Body.Close()

	info.Service = "HTTP"

	// Check for server header
	if server := resp.Header.Get("Server"); server != "" {
		info.Version = server
		info.Banner = fmt.Sprintf("HTTP/%s %d %s - Server: %s",
			resp.Proto, resp.StatusCode, resp.Status, server)
	} else {
		info.Banner = fmt.Sprintf("HTTP/%s %d %s", resp.Proto, resp.StatusCode, resp.Status)
	}
}

func (sd *ServiceDetector) detectHTTPS(info *ServiceInfo) {
	client := &http.Client{
		Timeout: 2 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	url := fmt.Sprintf("https://%s:%d/", info.Target, info.Port)
	resp, err := client.Get(url)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for HTTPS detection")
		return
	}
	defer resp.Body.Close()

	info.Service = "HTTPS"

	// Check for server header
	if server := resp.Header.Get("Server"); server != "" {
		info.Version = server
		info.Banner = fmt.Sprintf("HTTPS/%s %d %s - Server: %s",
			resp.Proto, resp.StatusCode, resp.Status, server)
	} else {
		info.Banner = fmt.Sprintf("HTTPS/%s %d %s", resp.Proto, resp.StatusCode, resp.Status)
	}
}

func (sd *ServiceDetector) detectMySQL(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for MySQL detection")
		return
	}
	defer conn.Close()

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	// Read MySQL handshake packet
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)
	if err != nil && err != io.EOF {
		log.WithError(err).Debug("Failed to read MySQL banner")
		return
	}

	if n > 4 {
		// MySQL packet has specific structure
		// Check for protocol version (usually 10)
		if buf[4] == 10 {
			info.Service = "MySQL"
			// Try to extract version string
			versionEnd := 5
			for i := 5; i < n && buf[i] != 0; i++ {
				versionEnd = i
			}
			if versionEnd > 5 {
				info.Version = string(buf[5:versionEnd])
				info.Banner = fmt.Sprintf("MySQL %s", info.Version)
			}
		}
	}
}

func (sd *ServiceDetector) detectPostgreSQL(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for PostgreSQL detection")
		return
	}
	defer conn.Close()

	// Send a startup message
	startupMsg := []byte{
		0x00, 0x00, 0x00, 0x08, // Length
		0x04, 0xd2, 0x16, 0x2f, // Cancel request code
	}

	conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	if _, err := conn.Write(startupMsg); err != nil {
		log.WithError(err).Debug("Failed to send PostgreSQL startup message")
		return
	}

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)

	// Even if we get an error, if we got some data, it might be PostgreSQL
	if n > 0 || (err != nil && strings.Contains(err.Error(), "connection reset")) {
		info.Service = "PostgreSQL"
		info.Banner = "PostgreSQL server"
	}
}

func (sd *ServiceDetector) detectRedis(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for Redis detection")
		return
	}
	defer conn.Close()

	// Send PING command
	conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	if _, err := conn.Write([]byte("*1\r\n$4\r\nPING\r\n")); err != nil {
		log.WithError(err).Debug("Failed to send Redis PING")
		return
	}

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	reader := bufio.NewReader(conn)
	response, err := reader.ReadString('\n')
	if err != nil && err != io.EOF {
		log.WithError(err).Debug("Failed to read Redis response")
		return
	}

	if strings.Contains(response, "PONG") || strings.HasPrefix(response, "+") {
		info.Service = "Redis"

		// Try to get server info
		conn.Write([]byte("*1\r\n$4\r\nINFO\r\n"))
		infoData := make([]byte, 1024)
		n, _ := reader.Read(infoData)
		if n > 0 {
			infoStr := string(infoData[:n])
			if strings.Contains(infoStr, "redis_version") {
				lines := strings.Split(infoStr, "\n")
				for _, line := range lines {
					if strings.HasPrefix(line, "redis_version:") {
						info.Version = strings.TrimPrefix(line, "redis_version:")
						info.Version = strings.TrimSpace(info.Version)
						break
					}
				}
			}
		}

		if info.Version != "" {
			info.Banner = fmt.Sprintf("Redis %s", info.Version)
		} else {
			info.Banner = "Redis server"
		}
	}
}

func (sd *ServiceDetector) detectMongoDB(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for MongoDB detection")
		return
	}
	defer conn.Close()

	// MongoDB wire protocol - send isMaster command
	isMasterCmd := []byte{
		0x3a, 0x00, 0x00, 0x00, // Message Length
		0x00, 0x00, 0x00, 0x00, // Request ID
		0x00, 0x00, 0x00, 0x00, // Response To
		0xd4, 0x07, 0x00, 0x00, // OpCode (OP_QUERY)
		0x00, 0x00, 0x00, 0x00, // Flags
		0x61, 0x64, 0x6d, 0x69, 0x6e, 0x2e, 0x24, 0x63, 0x6d, 0x64, 0x00, // Collection name
		0x00, 0x00, 0x00, 0x00, // Number to skip
		0x01, 0x00, 0x00, 0x00, // Number to return
		// BSON document for isMaster
		0x18, 0x00, 0x00, 0x00,
		0x10, 0x69, 0x73, 0x4d, 0x61, 0x73, 0x74, 0x65, 0x72, 0x00,
		0x01, 0x00, 0x00, 0x00,
		0x00,
	}

	conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	if _, err := conn.Write(isMasterCmd); err != nil {
		log.WithError(err).Debug("Failed to send MongoDB isMaster")
		return
	}

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)

	if n > 0 {
		// Check for MongoDB response pattern
		info.Service = "MongoDB"
		info.Banner = "MongoDB server"
	}
}

func (sd *ServiceDetector) grabBanner(info *ServiceInfo) {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", info.Target, info.Port), 2*time.Second)
	if err != nil {
		log.WithError(err).Debug("Failed to connect for banner grabbing")
		return
	}
	defer conn.Close()

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	// Try to read any banner
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)
	if err != nil && err != io.EOF && n == 0 {
		// Try sending a newline to trigger response
		conn.Write([]byte("\r\n"))
		conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		n, err = conn.Read(buf)
	}

	if n > 0 {
		banner := string(buf[:n])
		// Clean up the banner
		banner = strings.TrimSpace(banner)
		banner = strings.ReplaceAll(banner, "\r", "")
		banner = strings.ReplaceAll(banner, "\n", " ")

		if len(banner) > 200 {
			banner = banner[:200] + "..."
		}

		info.Banner = banner

		// Try to guess service from banner
		bannerLower := strings.ToLower(banner)
		switch {
		case strings.Contains(bannerLower, "ftp"):
			info.Service = "FTP"
		case strings.Contains(bannerLower, "smtp"):
			info.Service = "SMTP"
		case strings.Contains(bannerLower, "pop3"):
			info.Service = "POP3"
		case strings.Contains(bannerLower, "imap"):
			info.Service = "IMAP"
		case strings.Contains(bannerLower, "http"):
			info.Service = "HTTP"
		case strings.Contains(bannerLower, "ssh"):
			info.Service = "SSH"
		default:
			if info.Service == "" {
				info.Service = "Unknown"
			}
		}
	}
}

func (sd *ServiceDetector) publishServiceInfo(info ServiceInfo) {
	data, err := json.Marshal(info)
	if err != nil {
		log.WithError(err).Error("Failed to marshal service info")
		return
	}

	if err := sd.nc.Publish("service.detected", data); err != nil {
		log.WithError(err).Error("Failed to publish service info")
		return
	}

	log.WithFields(logrus.Fields{
		"target":  info.Target,
		"port":    info.Port,
		"service": info.Service,
		"version": info.Version,
	}).Info("Service detected and published")
}

func (sd *ServiceDetector) Shutdown() {
	log.Info("Shutting down analyzer agent")

	// Cancel context
	sd.cancel()

	// Wait for goroutines
	done := make(chan struct{})
	go func() {
		sd.wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.Info("All service detections completed")
	case <-time.After(5 * time.Second):
		log.Warn("Timeout waiting for service detections to complete")
	}

	// Close NATS connection
	if sd.nc != nil {
		sd.nc.Drain()
		sd.nc.Close()
	}

	log.Info("Analyzer agent shutdown complete")
}

func main() {
	// Configure logger
	log.SetFormatter(&logrus.TextFormatter{
		FullTimestamp: true,
		ForceColors:   true,
	})

	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}

	level, err := logrus.ParseLevel(logLevel)
	if err != nil {
		log.WithError(err).Warn("Invalid log level, defaulting to info")
		level = logrus.InfoLevel
	}
	log.SetLevel(level)

	log.Info("Starting Analyzer Agent")

	// Create service detector
	detector := NewServiceDetector()

	// Connect to NATS
	if err := detector.Connect(); err != nil {
		log.WithError(err).Fatal("Failed to connect to NATS")
	}

	// Subscribe to topics
	if err := detector.Subscribe(); err != nil {
		log.WithError(err).Fatal("Failed to subscribe to topics")
	}

	// Setup signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	log.Info("Analyzer Agent is running. Press Ctrl+C to stop")

	// Wait for shutdown signal
	<-sigChan

	// Graceful shutdown
	detector.Shutdown()
}