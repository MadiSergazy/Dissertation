# Pentool - Distributed Golang Penetration Testing Tool

[![Go Version](https://img.shields.io/badge/Go-1.24+-blue.svg)](https://golang.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-Multi--Agent-orange.svg)](#architecture)

> A modern, distributed penetration testing tool built with Go, featuring a multi-agent architecture for scalable network reconnaissance and service detection.

## 🎯 Project Overview

**Pentool** is a research-focused penetration testing framework developed for academic purposes, specifically for a master's dissertation on "Research on security tools using Golang for penetration testing". The tool demonstrates modern Go concurrency patterns, microservices architecture, and distributed system design principles.

## 🚀 Quick Start & Demo

### Prerequisites
- Go 1.19+, Docker & Docker Compose, Make

### 1. Setup & Start System
```bash
# Install dependencies and setup environment
make dev

# Start all services and agents
./scripts/start-system.sh
```

### 2. Run Interactive Demo
```bash
# Complete system demonstration
./scripts/demo.sh
```

### 3. Test API
```bash
# API testing suite
./scripts/test-api.sh
```

## 💻 Usage Examples

```bash
# Start a scan
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}'

# Check scan status
curl http://localhost:8080/scan/{scan-id}

# Health check
curl http://localhost:8080/health
```

## 🏗 Multi-Agent Architecture

```
Main Agent (REST API) ← HTTP ← Users
     ↕ NATS
Scanner Agent → Port Scanning → Results
     ↕ NATS
Analyzer Agent → Service Detection → Info
     ↕ NATS
Reporter Agent → JSON Reports → PostgreSQL
```

### Key Features
- 🔄 Multi-Agent distributed system
- 🚀 Concurrent Go goroutines scanning
- 📨 NATS message-driven communication
- 💾 PostgreSQL data persistence
- 🔍 Automated service detection
- 🐳 Docker containerized deployment

## 🔧 Development

```bash
make build       # Build all agents
make docker-up   # Start infrastructure
make test        # Run tests
make clean       # Clean everything
```

## 🚀 Manual Agent Startup

If you need to run agents manually (for debugging or development):

### Step 1: Start Infrastructure
```bash
# Start Docker services (NATS, PostgreSQL, Redis)
docker-compose -f deployments/docker-compose.yml up -d

# Verify services are running
docker-compose -f deployments/docker-compose.yml ps

# Initialize database (first time only)
docker exec -i pentool-postgres psql -U admin -d pentool < scripts/init-db.sql
```

### Step 2: Environment Variables
```bash
# Required environment variables
export DATABASE_URL="postgres://admin:secret123@localhost:15433/pentool?sslmode=disable"
export NATS_URL="nats://localhost:4222"
```

### Step 3: Run Agents (in separate terminals)

**Terminal 1 - Main Agent (REST API):**
```bash
DATABASE_URL="postgres://admin:secret123@localhost:15433/pentool?sslmode=disable" \
NATS_URL="nats://localhost:4222" \
go run cmd/main-agent/main.go
```

**Terminal 2 - Scanner Agent:**
```bash
NATS_URL="nats://localhost:4222" \
go run cmd/scanner-agent/main.go
```

**Terminal 3 - Analyzer Agent:**
```bash
NATS_URL="nats://localhost:4222" \
go run cmd/analyzer-agent/main.go
```

**Terminal 4 - Reporter Agent:**
```bash
DATABASE_URL="postgres://admin:secret123@localhost:15433/pentool?sslmode=disable" \
NATS_URL="nats://localhost:4222" \
go run cmd/reporter-agent/main.go
```

### Step 4: Test the System
```bash
# Health check
curl http://localhost:8080/health

# Run a scan
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}'

# Check results (replace {scan-id} with actual ID)
curl http://localhost:8080/scan/{scan-id}
```

### Port Configuration
| Service    | Default Port | Current Port |
|------------|--------------|--------------|
| Main Agent | 8080         | 8080         |
| NATS       | 4222         | 4222         |
| NATS HTTP  | 8222         | 8222         |
| PostgreSQL | 5432         | **15433**    |
| Redis      | 6379         | **16380**    |

> **Note:** PostgreSQL and Redis use non-standard ports to avoid conflicts with other local services.

## 🎓 Academic Research Value

**Technical Demonstrations:**
1. Go concurrency patterns with goroutines
2. Microservices architecture design
3. Message-driven distributed systems
4. Production-ready error handling
5. Scalable security tool development

**Research Applications:**
- Performance benchmarking vs existing tools
- Horizontal scaling studies
- Security architecture patterns
- Comparative analysis methodologies

## 📊 System Monitoring

- **Main Agent**: http://localhost:8080/health
- **NATS**: http://localhost:8222/healthz
- **Logs**: `tail -f logs/*.log`
- **Database**: `docker exec -it pentool-postgres psql -U admin -d pentool`

## 🔒 Legal & Ethical Usage

⚠️ **Only scan systems you own or have explicit permission to test**

**Safe Test Targets:**
- `scanme.nmap.org` - Official Nmap test server
- `localhost` - Your own system
- Private lab environments

---

*Developed for master's dissertation research on "Security tools using Golang for penetration testing"*

**Quick Demo Command:** `./scripts/demo.sh`