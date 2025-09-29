#!/bin/bash

# Benchmark script for Pentool performance testing
# Compares Pentool vs Nmap vs Masscan

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test targets
TARGET="scanme.nmap.org"
LOCALHOST="127.0.0.1"

# Ports to scan
COMMON_PORTS="21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017"
PORT_RANGE="1-1000"

# Results directory
RESULTS_DIR="benchmark_results"
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       Pentool Performance Benchmark Suite            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to measure execution time
measure_time() {
    local tool=$1
    local command=$2
    local output_file=$3

    echo -e "${YELLOW}Testing $tool...${NC}"

    # Clear cache
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

    # Measure time and memory
    /usr/bin/time -v bash -c "$command" 2>&1 | tee "$output_file"

    echo -e "${GREEN}✓ $tool test completed${NC}\n"
}

# Test 1: Common Ports Scan (15 ports)
echo -e "${BLUE}Test 1: Common Ports Scan (15 ports)${NC}"
echo "Target: $TARGET"
echo "Ports: $COMMON_PORTS"
echo ""

# Pentool test
echo -e "${YELLOW}1.1 Testing Pentool (via API)...${NC}"
start_time=$(date +%s%N)
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d "{\"target\":\"$TARGET\"}" \
  -o "$RESULTS_DIR/pentool_common_response.json" 2>/dev/null
end_time=$(date +%s%N)
pentool_time=$(( (end_time - start_time) / 1000000 ))
echo "Pentool execution time: ${pentool_time}ms"
sleep 5  # Wait for scan to complete

# Nmap test
echo -e "${YELLOW}1.2 Testing Nmap...${NC}"
measure_time "Nmap" \
    "nmap -p $COMMON_PORTS $TARGET -oN $RESULTS_DIR/nmap_common.txt" \
    "$RESULTS_DIR/nmap_common_metrics.txt"

# Test 2: Port Range Scan (1-1000)
echo -e "${BLUE}Test 2: Port Range Scan (1-1000 ports)${NC}"
echo "Target: $TARGET"
echo "Port range: $PORT_RANGE"
echo ""

# Nmap port range test
echo -e "${YELLOW}2.1 Testing Nmap (port range)...${NC}"
measure_time "Nmap Port Range" \
    "nmap -p $PORT_RANGE $TARGET -T4 -oN $RESULTS_DIR/nmap_range.txt" \
    "$RESULTS_DIR/nmap_range_metrics.txt"

# Test 3: Localhost Performance Test
echo -e "${BLUE}Test 3: Localhost Performance Test${NC}"
echo "Target: $LOCALHOST"
echo ""

# Start a simple test server
echo -e "${YELLOW}Starting test services...${NC}"
python3 -m http.server 8888 > /dev/null 2>&1 &
HTTP_SERVER_PID=$!
sleep 2

# Nmap localhost test
echo -e "${YELLOW}3.1 Testing Nmap (localhost)...${NC}"
measure_time "Nmap Localhost" \
    "nmap -p 1-1000 $LOCALHOST -T4 -oN $RESULTS_DIR/nmap_localhost.txt" \
    "$RESULTS_DIR/nmap_localhost_metrics.txt"

# Cleanup
kill $HTTP_SERVER_PID 2>/dev/null || true

# Test 4: Service Detection Comparison
echo -e "${BLUE}Test 4: Service Detection Test${NC}"
echo "Target: $TARGET"
echo ""

# Nmap with service detection
echo -e "${YELLOW}4.1 Testing Nmap (with -sV)...${NC}"
measure_time "Nmap Service Detection" \
    "nmap -p $COMMON_PORTS -sV $TARGET -oN $RESULTS_DIR/nmap_service.txt" \
    "$RESULTS_DIR/nmap_service_metrics.txt"

# Extract metrics
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Benchmark Results Summary               ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to extract time from /usr/bin/time output
extract_metric() {
    local file=$1
    local metric=$2

    case $metric in
        "elapsed")
            grep "Elapsed (wall clock) time" "$file" | awk '{print $8}' || echo "N/A"
            ;;
        "memory")
            grep "Maximum resident set size" "$file" | awk '{print $6}' || echo "N/A"
            ;;
        "cpu")
            grep "Percent of CPU" "$file" | awk '{print $7}' | tr -d '%' || echo "N/A"
            ;;
    esac
}

# Display results
echo "Test 1 - Common Ports (15 ports):"
echo "  Pentool API: ${pentool_time}ms"
if [ -f "$RESULTS_DIR/nmap_common_metrics.txt" ]; then
    nmap_time=$(extract_metric "$RESULTS_DIR/nmap_common_metrics.txt" "elapsed")
    nmap_mem=$(extract_metric "$RESULTS_DIR/nmap_common_metrics.txt" "memory")
    echo "  Nmap: $nmap_time (Memory: ${nmap_mem}KB)"
fi
echo ""

echo "Test 2 - Port Range (1-1000):"
if [ -f "$RESULTS_DIR/nmap_range_metrics.txt" ]; then
    nmap_time=$(extract_metric "$RESULTS_DIR/nmap_range_metrics.txt" "elapsed")
    nmap_mem=$(extract_metric "$RESULTS_DIR/nmap_range_metrics.txt" "memory")
    echo "  Nmap: $nmap_time (Memory: ${nmap_mem}KB)"
fi
echo ""

echo "Test 3 - Localhost (1-1000):"
if [ -f "$RESULTS_DIR/nmap_localhost_metrics.txt" ]; then
    nmap_time=$(extract_metric "$RESULTS_DIR/nmap_localhost_metrics.txt" "elapsed")
    nmap_mem=$(extract_metric "$RESULTS_DIR/nmap_localhost_metrics.txt" "memory")
    echo "  Nmap: $nmap_time (Memory: ${nmap_mem}KB)"
fi
echo ""

echo "Test 4 - Service Detection:"
if [ -f "$RESULTS_DIR/nmap_service_metrics.txt" ]; then
    nmap_time=$(extract_metric "$RESULTS_DIR/nmap_service_metrics.txt" "elapsed")
    nmap_mem=$(extract_metric "$RESULTS_DIR/nmap_service_metrics.txt" "memory")
    echo "  Nmap -sV: $nmap_time (Memory: ${nmap_mem}KB)"
fi
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}All benchmark tests completed!${NC}"
echo -e "${GREEN}Results saved in: $RESULTS_DIR/${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"