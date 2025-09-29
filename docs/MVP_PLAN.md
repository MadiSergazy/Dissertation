MVP Development Plan - Golang Penetration Testing Tool
Project Overview
Goal: Build a minimal working penetration testing tool with main agent orchestrating multiple sub-agents
Timeline: 2-3 weeks for basic MVP
Architecture: Main Agent + 3 Sub-Agents (Scanner, Analyzer, Reporter)

Phase 1: Project Setup (Day 1)
1.1 Initialize Project Structure
pentool/
├── cmd/
│   ├── main-agent/
│   │   └── main.go
│   ├── scanner-agent/
│   │   └── main.go
│   ├── analyzer-agent/
│   │   └── main.go
│   └── reporter-agent/
│       └── main.go
├── internal/
│   ├── agent/
│   │   ├── types.go
│   │   └── communication.go
│   ├── scanner/
│   │   └── port_scanner.go
│   ├── analyzer/
│   │   └── service_detector.go
│   └── reporter/
│       └── json_reporter.go
├── pkg/
│   └── models/
│       └── scan.go
├── deployments/
│   ├── docker/
│   │   ├── Dockerfile.main
│   │   └── Dockerfile.agent
│   └── docker-compose.yml
├── configs/
│   └── config.yaml
├── scripts/
│   └── setup.sh
├── go.mod
├── go.sum
├── Makefile
└── README.md
1.2 Initialize Go Module
bashgo mod init github.com/yourusername/pentool
1.3 Install Essential Dependencies
bash# Core dependencies only for MVP
go get github.com/spf13/cobra@latest
go get github.com/nats-io/nats.go@latest
go get github.com/sirupsen/logrus@latest
go get github.com/lib/pq@latest

Phase 2: Core Infrastructure (Day 2-3)
2.1 Communication Layer (NATS)
File: internal/agent/communication.go
go// Implement basic pub-sub messaging
type Message struct {
ID        string
Type      string  // "scan_request", "scan_result", "analyze_request", etc.
Payload   []byte
Timestamp time.Time
}
2.2 Database Schema
File: deployments/postgres/init.sql
sqlCREATE TABLE scans (
id SERIAL PRIMARY KEY,
target VARCHAR(255),
status VARCHAR(50),
created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE results (
id SERIAL PRIMARY KEY,
scan_id INTEGER REFERENCES scans(id),
port INTEGER,
state VARCHAR(20),
service VARCHAR(100),
created_at TIMESTAMP DEFAULT NOW()
);
2.3 Docker Compose Setup
File: deployments/docker-compose.yml
yamlversion: '3.8'
services:
postgres:
image: postgres:15-alpine
environment:
POSTGRES_DB: pentool
POSTGRES_USER: admin
POSTGRES_PASSWORD: secret
ports:
- "5432:5432"

redis:
image: redis:7-alpine
ports:
- "6379:6379"

nats:
image: nats:2.10-alpine
ports:
- "4222:4222"

Phase 3: Main Agent Implementation (Day 4-5)
3.1 Main Agent Core
Responsibilities:

Receive scan requests via REST API
Distribute tasks to sub-agents
Monitor task progress
Aggregate results

Key Files:

cmd/main-agent/main.go - Entry point with Cobra CLI
internal/agent/coordinator.go - Task distribution logic
internal/api/handlers.go - REST endpoints

3.2 REST API Endpoints
POST /scan          - Start new scan
GET  /scan/:id      - Get scan status
GET  /scan/:id/results - Get scan results
GET  /health        - Health check

Phase 4: Sub-Agent Implementation (Day 6-8)
4.1 Scanner Agent
File: cmd/scanner-agent/main.go
Responsibilities:

Listen for scan tasks from NATS
Perform TCP port scanning (top 100 ports only for MVP)
Publish results back to NATS

Core Logic:
go// Simple TCP port scanner
func ScanPort(host string, port int, timeout time.Duration) bool {
conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", host, port), timeout)
if err != nil {
return false
}
conn.Close()
return true
}
4.2 Analyzer Agent
File: cmd/analyzer-agent/main.go
Responsibilities:

Receive open port data
Perform basic service detection (banner grabbing)
Identify common services (HTTP, SSH, FTP)

4.3 Reporter Agent
File: cmd/reporter-agent/main.go
Responsibilities:

Aggregate scan results
Generate JSON reports
Store results in PostgreSQL


Phase 5: Integration & Testing (Day 9-10)
5.1 Integration Testing Script
File: scripts/test-integration.sh
bash#!/bin/bash
# Start all services
docker-compose up -d
# Wait for services
sleep 10
# Start agents
./bin/main-agent &
./bin/scanner-agent &
./bin/analyzer-agent &
./bin/reporter-agent &
# Run test scan
curl -X POST http://localhost:8080/scan -d '{"target":"scanme.nmap.org"}'
5.2 Makefile Commands
makefilebuild:
go build -o bin/main-agent cmd/main-agent/main.go
go build -o bin/scanner-agent cmd/scanner-agent/main.go
go build -o bin/analyzer-agent cmd/analyzer-agent/main.go
go build -o bin/reporter-agent cmd/reporter-agent/main.go

run:
docker-compose up -d
./bin/main-agent

test:
go test ./...

clean:
docker-compose down
rm -rf bin/

Implementation Order for Sub-Agents
Step 1: Basic Message Types
go// pkg/models/scan.go
type ScanRequest struct {
ID     string
Target string
Ports  []int
}

type ScanResult struct {
ID       string
Target   string
Port     int
IsOpen   bool
Service  string
Banner   string
}
Step 2: NATS Connection Helper
go// internal/agent/nats_helper.go
func ConnectNATS(url string) (*nats.Conn, error)
func PublishMessage(nc *nats.Conn, subject string, data interface{}) error
func SubscribeToTopic(nc *nats.Conn, subject string, handler func(msg *nats.Msg)) error
Step 3: Scanner Agent Core Loop
go// Pseudo-code for scanner agent
func main() {
nc := connectToNATS()
subscribeToScanRequests(nc, func(request ScanRequest) {
results := scanPorts(request.Target, request.Ports)
publishResults(nc, results)
})
}
Step 4: Main Agent Orchestration
go// Pseudo-code for main agent
func handleScanRequest(target string) {
scanID := generateID()
// Store in DB
createScan(scanID, target, "pending")
// Publish to scanner queue
publishToNATS("scan.request", ScanRequest{ID: scanID, Target: target})
// Return scan ID to user
return scanID
}

Quick Start Commands
bash# Day 1: Setup
mkdir pentool && cd pentool
go mod init github.com/yourusername/pentool
mkdir -p cmd/{main-agent,scanner-agent,analyzer-agent,reporter-agent}
mkdir -p internal/{agent,scanner,analyzer,reporter}
mkdir -p pkg/models deployments/docker configs scripts

# Day 2: Start services
docker-compose -f deployments/docker-compose.yml up -d

# Day 3-8: Implement each component
# Use the structure above to implement each agent

# Day 9: Build everything
make build

# Day 10: Test
make test
./scripts/test-integration.sh

MVP Features Checklist
Must Have (Week 1)

Basic TCP port scanning (top 100 ports)
NATS message passing between agents
Simple REST API for scan submission
JSON result output
Docker compose for dependencies

Should Have (Week 2)

PostgreSQL result storage
Basic service detection
Concurrent scanning with goroutines
Simple web UI (optional)
Rate limiting

Could Have (Week 3)

Redis caching
Advanced service fingerprinting
Scan scheduling
Multiple target support
Progress tracking


Testing Targets for Development
Safe Legal Targets

scanme.nmap.org - Official test server
localhost - Your own machine
Docker containers - DVWA, WebGoat
Private network VMs - VulnHub machines

Test Commands
bash# Test main agent API
curl http://localhost:8080/health

# Submit scan
curl -X POST http://localhost:8080/scan \
-H "Content-Type: application/json" \
-d '{"target": "scanme.nmap.org", "ports": [22, 80, 443]}'

# Check results
curl http://localhost:8080/scan/{scan-id}/results

Common Issues & Solutions

NATS Connection Issues

Ensure NATS is running: docker ps | grep nats
Check connection string: nats://localhost:4222


Port Scanner Timeouts

Use shorter timeout for MVP: 1 second
Implement connection pooling


Database Connection

Wait for PostgreSQL to be ready
Use connection retry logic




Next Steps After MVP

Security Enhancements

Add authentication to API
Implement TLS for agent communication
Add input validation


Performance Optimization

Implement worker pools
Add caching layer
Optimize database queries


Feature Expansion

UDP scanning
Vulnerability detection
Report generation (PDF/HTML)




Success Metrics for MVP

Can scan single target
Detects open ports accurately
All agents communicate successfully
Results stored in database
API returns results within 30 seconds
System handles agent failures gracefully


Resources & References

NATS Go Client
Cobra CLI Framework
Docker Compose Documentation
Go Concurrency Patterns


Timeline Summary
Week 1 (Days 1-7)

Project setup ✓
Basic agents implementation ✓
Core scanning functionality ✓

Week 2 (Days 8-14)

Integration testing
Bug fixes
Documentation
Basic UI (optional)

Week 3 (Days 15-21)

Performance optimization
Additional features
Preparation for thesis