#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_header() {
    echo
    echo -e "${PURPLE}=== $1 ===${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

wait_for_input() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Demo script
clear
echo -e "${PURPLE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║           PENTOOL DEMONSTRATION           ║
║      Golang Penetration Testing Tool     ║
║         Multi-Agent Architecture          ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "This demo will showcase the capabilities of our distributed penetration testing tool"
print_info "Architecture: Main Agent + 3 Sub-Agents (Scanner, Analyzer, Reporter)"
wait_for_input

print_header "1. System Health Check"

print_step "Checking Main Agent API..."
if curl -s http://localhost:8080/health | jq . 2>/dev/null; then
    print_success "Main Agent is healthy!"
else
    echo "ERROR: Main Agent is not running. Please run './scripts/start-system.sh' first"
    exit 1
fi

wait_for_input

print_header "2. Starting Port Scan"

TARGET="scanme.nmap.org"
print_step "Scanning target: $TARGET"
print_info "This will scan the top 20 most common ports"

# Start scan and capture scan ID
RESPONSE=$(curl -s -X POST http://localhost:8080/scan \
    -H "Content-Type: application/json" \
    -d "{\"target\":\"$TARGET\"}" | jq -r '.scan_id')

if [ "$RESPONSE" = "null" ] || [ -z "$RESPONSE" ]; then
    echo "ERROR: Failed to start scan"
    exit 1
fi

SCAN_ID=$RESPONSE
print_success "Scan started with ID: $SCAN_ID"

wait_for_input

print_header "3. Monitoring Scan Progress"

print_step "Checking scan status..."
for i in {1..10}; do
    STATUS_RESPONSE=$(curl -s "http://localhost:8080/scan/$SCAN_ID")
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
    OPEN_PORTS=$(echo "$STATUS_RESPONSE" | jq -r '.open_ports')
    TOTAL_PORTS=$(echo "$STATUS_RESPONSE" | jq -r '.total_ports')

    echo "Status: $STATUS | Progress: $OPEN_PORTS/$TOTAL_PORTS ports checked"

    if [ "$STATUS" = "completed" ]; then
        print_success "Scan completed!"
        break
    fi

    sleep 3
done

wait_for_input

print_header "4. Scan Results"

print_step "Fetching detailed results..."
RESULTS=$(curl -s "http://localhost:8080/scan/$SCAN_ID")

echo "Full scan results:"
echo "$RESULTS" | jq .

print_info "Key information extracted:"
echo "$RESULTS" | jq -r '
  "Target: " + .target,
  "Status: " + .status,
  "Total Ports: " + (.total_ports | tostring),
  "Open Ports: " + (.open_ports | tostring),
  "Duration: " + ((.completed_at | fromdateiso8601) - (.created_at | fromdateiso8601) | tostring) + " seconds"
'

wait_for_input

print_header "5. Database Verification"

print_step "Checking data in PostgreSQL..."

echo "Recent scans in database:"
docker exec -i pentool-postgres psql -U admin -d pentool -c "
    SELECT id, target, status, total_ports, open_ports, created_at
    FROM scans
    ORDER BY created_at DESC
    LIMIT 3;
" 2>/dev/null

echo
echo "Port scan results for this scan:"
docker exec -i pentool-postgres psql -U admin -d pentool -c "
    SELECT port, state, protocol
    FROM scan_results
    WHERE scan_id = '$SCAN_ID' AND state = 'open'
    ORDER BY port;
" 2>/dev/null

wait_for_input

print_header "6. Service Detection Results"

echo "Detected services:"
docker exec -i pentool-postgres psql -U admin -d pentool -c "
    SELECT port, service_name, version, confidence
    FROM services
    WHERE scan_id = '$SCAN_ID'
    ORDER BY port;
" 2>/dev/null

wait_for_input

print_header "7. Generated Reports"

echo "Available reports:"
docker exec -i pentool-postgres psql -U admin -d pentool -c "
    SELECT scan_id, report_type, created_at
    FROM reports
    WHERE scan_id = '$SCAN_ID';
" 2>/dev/null

print_step "Retrieving JSON report..."
REPORT=$(docker exec -i pentool-postgres psql -U admin -d pentool -t -A -c "
    SELECT report_data
    FROM reports
    WHERE scan_id = '$SCAN_ID'
    LIMIT 1;
" 2>/dev/null | tr -d '[:space:]')

if [ -n "$REPORT" ]; then
    echo "Generated report:"
    echo "$REPORT" | jq .
else
    print_info "Report may still be generating..."
fi

wait_for_input

print_header "8. System Architecture Demonstration"

print_info "Let's examine how the multi-agent system works:"
echo
echo "1. 🎯 Main Agent (REST API)"
echo "   • Receives scan requests via HTTP"
echo "   • Manages scan lifecycle in PostgreSQL"
echo "   • Coordinates other agents via NATS"
echo
echo "2. 🔍 Scanner Agent"
echo "   • Listens for scan requests on NATS"
echo "   • Performs concurrent TCP port scanning"
echo "   • Publishes results back to NATS"
echo
echo "3. 🔬 Analyzer Agent"
echo "   • Listens for scan results on NATS"
echo "   • Performs service detection and banner grabbing"
echo "   • Identifies services like SSH, HTTP, MySQL, etc."
echo
echo "4. 📊 Reporter Agent"
echo "   • Aggregates all scan data"
echo "   • Generates comprehensive JSON reports"
echo "   • Updates scan status to completed"

wait_for_input

print_header "9. Performance Metrics"

print_step "Analyzing system performance..."

# Get timing information
SCAN_DATA=$(curl -s "http://localhost:8080/scan/$SCAN_ID")
START_TIME=$(echo "$SCAN_DATA" | jq -r '.created_at')
END_TIME=$(echo "$SCAN_DATA" | jq -r '.completed_at')

if [ "$END_TIME" != "null" ] && [ -n "$END_TIME" ]; then
    print_info "Scan Performance:"
    echo "• Start Time: $START_TIME"
    echo "• End Time: $END_TIME"

    # Calculate duration (simplified)
    print_info "• Scanned 20 ports on $TARGET"
    print_info "• Used concurrent goroutines for parallel scanning"
    print_info "• Performed service detection on open ports"
    print_info "• Generated comprehensive report with statistics"
fi

wait_for_input

print_header "10. Additional Demonstration Commands"

echo "You can explore further with these commands:"
echo
echo "# Start a new scan of different target"
echo "curl -X POST http://localhost:8080/scan -H 'Content-Type: application/json' -d '{\"target\":\"localhost\"}'"
echo
echo "# Monitor NATS messages in real-time"
echo "docker exec -it pentool-nats nats sub 'scan.*'"
echo
echo "# View live logs from any agent"
echo "tail -f logs/scanner-agent.log"
echo
echo "# Query database directly"
echo "docker exec -it pentool-postgres psql -U admin -d pentool"
echo
echo "# Check Redis cache"
echo "docker exec -it pentool-redis redis-cli"

print_header "Demo Complete!"

print_success "🎉 Pentool demonstration finished successfully!"
print_info "The system showcased:"
echo "✅ Multi-agent distributed architecture"
echo "✅ Real-time message passing with NATS"
echo "✅ Concurrent port scanning with Go goroutines"
echo "✅ Service detection and banner grabbing"
echo "✅ PostgreSQL data persistence"
echo "✅ RESTful API interface"
echo "✅ Comprehensive reporting"
echo "✅ Graceful error handling"

echo
print_info "For your dissertation, this demonstrates:"
echo "• Modern Go concurrency patterns"
echo "• Microservices architecture"
echo "• Message-driven design"
echo "• Scalable security tool development"
echo "• Production-ready error handling and logging"