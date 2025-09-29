#!/bin/bash

# Simple Benchmark script for Pentool performance testing

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET="scanme.nmap.org"
COMMON_PORTS="21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017"

RESULTS_DIR="benchmark_results"
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       Pentool Performance Benchmark Suite            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Test 1: Pentool Common Ports
echo -e "${BLUE}Test 1: Pentool - Common Ports Scan (15 ports)${NC}"
echo "Target: $TARGET"
echo ""

echo -e "${YELLOW}Starting Pentool scan...${NC}"
start_time=$(date +%s%N)
SCAN_ID=$(curl -s -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d "{\"target\":\"$TARGET\"}" | jq -r '.id')

echo "Scan ID: $SCAN_ID"
echo "Waiting for scan to complete..."

# Wait for scan completion (max 60 seconds)
for i in {1..60}; do
    sleep 1
    STATUS=$(curl -s http://localhost:8080/scan/$SCAN_ID | jq -r '.status')
    echo -n "."
    if [ "$STATUS" == "completed" ] || [ "$STATUS" == "failed" ]; then
        break
    fi
done
echo ""

end_time=$(date +%s%N)
pentool_time=$(( (end_time - start_time) / 1000000 ))

# Get results
curl -s http://localhost:8080/scan/$SCAN_ID | jq . > "$RESULTS_DIR/pentool_scan_results.json"

OPEN_PORTS=$(curl -s http://localhost:8080/scan/$SCAN_ID | jq '.open_ports')
echo -e "${GREEN}✓ Pentool completed in ${pentool_time}ms${NC}"
echo "  Open ports found: $OPEN_PORTS"
echo ""

# Test 2: Nmap Common Ports
echo -e "${BLUE}Test 2: Nmap - Common Ports Scan (15 ports)${NC}"
echo "Target: $TARGET"
echo ""

echo -e "${YELLOW}Starting Nmap scan...${NC}"
start_time=$(date +%s%N)
/usr/bin/time -f "Time: %E\nMemory: %M KB\nCPU: %P" \
    nmap -p $COMMON_PORTS $TARGET -oN "$RESULTS_DIR/nmap_common.txt" \
    2> "$RESULTS_DIR/nmap_common_time.txt" > /dev/null

end_time=$(date +%s%N)
nmap_time=$(( (end_time - start_time) / 1000000 ))

NMAP_OPEN=$(grep "open" "$RESULTS_DIR/nmap_common.txt" | wc -l)
echo -e "${GREEN}✓ Nmap completed in ${nmap_time}ms${NC}"
echo "  Open ports found: $NMAP_OPEN"
echo ""

# Test 3: Nmap Port Range (1-100 for speed)
echo -e "${BLUE}Test 3: Nmap - Port Range Scan (1-100)${NC}"
echo "Target: $TARGET"
echo ""

echo -e "${YELLOW}Starting Nmap port range scan...${NC}"
start_time=$(date +%s%N)
/usr/bin/time -f "Time: %E\nMemory: %M KB\nCPU: %P" \
    nmap -p 1-100 $TARGET -T4 -oN "$RESULTS_DIR/nmap_range.txt" \
    2> "$RESULTS_DIR/nmap_range_time.txt" > /dev/null

end_time=$(date +%s%N)
nmap_range_time=$(( (end_time - start_time) / 1000000 ))

NMAP_RANGE_OPEN=$(grep "open" "$RESULTS_DIR/nmap_range.txt" | wc -l)
echo -e "${GREEN}✓ Nmap completed in ${nmap_range_time}ms${NC}"
echo "  Open ports found: $NMAP_RANGE_OPEN"
echo ""

# Test 4: Nmap Service Detection
echo -e "${BLUE}Test 4: Nmap - Service Detection${NC}"
echo "Target: $TARGET"
echo ""

echo -e "${YELLOW}Starting Nmap service detection...${NC}"
start_time=$(date +%s%N)
/usr/bin/time -f "Time: %E\nMemory: %M KB\nCPU: %P" \
    nmap -p $COMMON_PORTS -sV $TARGET -oN "$RESULTS_DIR/nmap_service.txt" \
    2> "$RESULTS_DIR/nmap_service_time.txt" > /dev/null

end_time=$(date +%s%N)
nmap_svc_time=$(( (end_time - start_time) / 1000000 ))

echo -e "${GREEN}✓ Nmap service detection completed in ${nmap_svc_time}ms${NC}"
echo ""

# Generate summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Benchmark Results Summary               ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Create summary JSON
cat > "$RESULTS_DIR/summary.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "target": "$TARGET",
  "tests": {
    "pentool_common_ports": {
      "time_ms": $pentool_time,
      "open_ports": $OPEN_PORTS,
      "scan_id": "$SCAN_ID"
    },
    "nmap_common_ports": {
      "time_ms": $nmap_time,
      "open_ports": $NMAP_OPEN
    },
    "nmap_port_range_1_100": {
      "time_ms": $nmap_range_time,
      "open_ports": $NMAP_RANGE_OPEN
    },
    "nmap_service_detection": {
      "time_ms": $nmap_svc_time
    }
  }
}
EOF

echo "Test Results:"
echo ""
echo "1. Common Ports (15 ports):"
echo "   Pentool: ${pentool_time}ms (${OPEN_PORTS} open ports)"
echo "   Nmap:    ${nmap_time}ms (${NMAP_OPEN} open ports)"
echo ""
echo "2. Port Range (1-100):"
echo "   Nmap:    ${nmap_range_time}ms (${NMAP_RANGE_OPEN} open ports)"
echo ""
echo "3. Service Detection:"
echo "   Nmap:    ${nmap_svc_time}ms"
echo ""

# Extract metrics from time files
if [ -f "$RESULTS_DIR/nmap_common_time.txt" ]; then
    echo "Nmap Common Ports Metrics:"
    cat "$RESULTS_DIR/nmap_common_time.txt"
    echo ""
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}All benchmark tests completed!${NC}"
echo -e "${GREEN}Results saved in: $RESULTS_DIR/${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Run 'python3 scripts/analyze_results.py' to generate charts and analysis"