#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose; then
    print_error "docker-compose is not installed. Please install docker-compose first."
    exit 1
fi

if ! command_exists go; then
    print_error "Go is not installed. Please install Go 1.19+ first."
    exit 1
fi

print_success "All prerequisites are met!"

# Create bin directory if it doesn't exist
mkdir -p bin

print_step "Starting infrastructure services..."

# Stop any existing services
docker-compose -f deployments/docker-compose.yml down >/dev/null 2>&1 || true

# Start services
docker-compose -f deployments/docker-compose.yml up -d

print_step "Waiting for services to be ready..."

# Wait for PostgreSQL
echo -n "Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker exec pentool-postgres pg_isready -U admin -d pentool >/dev/null 2>&1; then
        echo " Ready!"
        break
    fi
    echo -n "."
    sleep 1
done

# Wait for NATS
echo -n "Waiting for NATS..."
for i in {1..30}; do
    if curl -s http://localhost:8222/healthz >/dev/null 2>&1; then
        echo " Ready!"
        break
    fi
    echo -n "."
    sleep 1
done

# Wait for Redis
echo -n "Waiting for Redis..."
for i in {1..30}; do
    if docker exec pentool-redis redis-cli ping >/dev/null 2>&1; then
        echo " Ready!"
        break
    fi
    echo -n "."
    sleep 1
done

print_success "All infrastructure services are ready!"

print_step "Building agents..."
make build

print_success "All agents built successfully!"

print_step "Starting agents..."

# Kill any existing agents
pkill -f "main-agent\|scanner-agent\|analyzer-agent\|reporter-agent" 2>/dev/null || true

# Start agents in background
nohup ./bin/main-agent > logs/main-agent.log 2>&1 &
MAIN_PID=$!
echo "Main Agent started (PID: $MAIN_PID)"

sleep 2

nohup ./bin/scanner-agent > logs/scanner-agent.log 2>&1 &
SCANNER_PID=$!
echo "Scanner Agent started (PID: $SCANNER_PID)"

sleep 2

nohup ./bin/analyzer-agent > logs/analyzer-agent.log 2>&1 &
ANALYZER_PID=$!
echo "Analyzer Agent started (PID: $ANALYZER_PID)"

sleep 2

nohup ./bin/reporter-agent > logs/reporter-agent.log 2>&1 &
REPORTER_PID=$!
echo "Reporter Agent started (PID: $REPORTER_PID)"

# Save PIDs to file
echo "$MAIN_PID $SCANNER_PID $ANALYZER_PID $REPORTER_PID" > .agent_pids

sleep 3

print_step "Checking agent status..."

# Check if main agent is responding
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    print_success "Main Agent is responding on http://localhost:8080"
else
    print_error "Main Agent is not responding! Check logs/main-agent.log"
    exit 1
fi

print_success "🚀 Pentool system is running!"
echo
echo "=== System Status ==="
echo "Main Agent API:    http://localhost:8080"
echo "NATS Monitoring:   http://localhost:8222"
echo "PostgreSQL:        localhost:5432"
echo "Redis:             localhost:6379"
echo
echo "=== Log Files ==="
echo "Main Agent:        tail -f logs/main-agent.log"
echo "Scanner Agent:     tail -f logs/scanner-agent.log"
echo "Analyzer Agent:    tail -f logs/analyzer-agent.log"
echo "Reporter Agent:    tail -f logs/reporter-agent.log"
echo
echo "=== Quick Test ==="
echo "curl -X POST http://localhost:8080/scan -H 'Content-Type: application/json' -d '{\"target\":\"scanme.nmap.org\"}'"
echo
echo "=== Stop System ==="
echo "./scripts/stop-system.sh"