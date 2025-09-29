#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_step "Stopping Pentool system..."

# Stop agents using saved PIDs
if [ -f .agent_pids ]; then
    print_step "Stopping agents..."
    PIDS=$(cat .agent_pids)
    for pid in $PIDS; do
        if kill -0 $pid 2>/dev/null; then
            kill -TERM $pid
            echo "Stopped process $pid"
        fi
    done
    rm .agent_pids
    print_success "All agents stopped!"
else
    print_step "Killing any running agents..."
    pkill -f "main-agent\|scanner-agent\|analyzer-agent\|reporter-agent" 2>/dev/null || true
fi

# Stop Docker services
print_step "Stopping infrastructure services..."
docker-compose -f deployments/docker-compose.yml down

print_success "🛑 Pentool system stopped!"