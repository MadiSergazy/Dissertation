#!/bin/bash

# Extended Experiments for Scientific Paper
# Tests Pentool vs Nmap performance at various port ranges

set -e

# Configuration
TARGET="scanme.nmap.org"
RUNS=3
OUTPUT_DIR="experiment_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Results file
RESULTS_FILE="$OUTPUT_DIR/results_${TIMESTAMP}.json"

echo "=============================================="
echo "Pentool vs Nmap Extended Experiments"
echo "Target: $TARGET"
echo "Runs per test: $RUNS"
echo "Results file: $RESULTS_FILE"
echo "=============================================="

# Function to generate port array for curl
generate_ports() {
    local count=$1
    local ports=""
    for ((i=1; i<=count; i++)); do
        if [ $i -eq 1 ]; then
            ports="$i"
        else
            ports="$ports,$i"
        fi
    done
    echo "[$ports]"
}

# Function to measure Pentool scan time
run_pentool_scan() {
    local port_count=$1
    local ports=$(generate_ports $port_count)

    local start_time=$(date +%s.%N)

    # Submit scan request
    local response=$(curl -s -X POST http://localhost:8080/scan \
        -H "Content-Type: application/json" \
        -d "{\"target\":\"$TARGET\",\"ports\":$ports}")

    local scan_id=$(echo "$response" | jq -r '.id')

    if [ -z "$scan_id" ] || [ "$scan_id" = "null" ]; then
        echo "ERROR: Failed to get scan ID"
        return 1
    fi

    # Wait for scan to complete
    local status="pending"
    local max_wait=300  # 5 minutes max
    local waited=0

    while [ "$status" = "pending" ] || [ "$status" = "running" ]; do
        sleep 0.5
        waited=$((waited + 1))
        if [ $waited -gt $((max_wait * 2)) ]; then
            echo "ERROR: Scan timeout"
            return 1
        fi

        local scan_result=$(curl -s "http://localhost:8080/scan/$scan_id")
        status=$(echo "$scan_result" | jq -r '.status')
        local scanned=$(echo "$scan_result" | jq -r '.open_ports // 0')
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    echo "$duration"
}

# Function to measure Nmap scan time
run_nmap_scan() {
    local port_count=$1

    local start_time=$(date +%s.%N)
    nmap -p 1-$port_count -T4 --min-parallelism 100 "$TARGET" > /dev/null 2>&1
    local end_time=$(date +%s.%N)

    local duration=$(echo "$end_time - $start_time" | bc)
    echo "$duration"
}

# Function to run multiple tests and get average
run_averaged_test() {
    local tool=$1
    local port_count=$2

    local total=0

    for ((run=1; run<=RUNS; run++)); do
        echo -n "  Run $run/$RUNS: "

        if [ "$tool" = "pentool" ]; then
            local time=$(run_pentool_scan $port_count)
        else
            local time=$(run_nmap_scan $port_count)
        fi

        echo "${time}s"
        total=$(echo "$total + $time" | bc)

        # Brief pause between runs
        sleep 1
    done

    local average=$(echo "scale=3; $total / $RUNS" | bc)
    echo "$average"
}

# Initialize JSON results
cat > "$RESULTS_FILE" << 'EOF'
{
  "experiment_date": "PLACEHOLDER_DATE",
  "environment": {},
  "volume_comparison": {},
  "scalability": {},
  "break_even_point": {},
  "observations": []
}
EOF

# Collect environment info
echo ""
echo "Collecting environment information..."
OS_INFO=$(lsb_release -d 2>/dev/null | cut -f2 || uname -a)
GO_VERSION=$(go version | awk '{print $3}')
CPU_INFO=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || echo "Unknown")
RAM_INFO=$(free -h | grep Mem | awk '{print $2}')

# Update JSON with environment
jq --arg date "$(date +%Y-%m-%d)" \
   --arg os "$OS_INFO" \
   --arg go "$GO_VERSION" \
   --arg cpu "$CPU_INFO" \
   --arg ram "$RAM_INFO" \
   '.experiment_date = $date | .environment = {os: $os, go_version: $go, cpu: $cpu, ram: $ram}' \
   "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"

echo "  OS: $OS_INFO"
echo "  Go: $GO_VERSION"
echo "  CPU: $CPU_INFO"
echo "  RAM: $RAM_INFO"

# ============================================
# EXPERIMENT A: Volume Comparison
# ============================================
echo ""
echo "=============================================="
echo "EXPERIMENT A: Volume Comparison (Pentool vs Nmap)"
echo "=============================================="

declare -a PORT_COUNTS=(100 500 1000 2000 5000)
declare -A PENTOOL_RESULTS
declare -A NMAP_RESULTS

for port_count in "${PORT_COUNTS[@]}"; do
    echo ""
    echo "=== Testing $port_count ports ==="

    echo "Pentool ($port_count ports):"
    pentool_time=$(run_averaged_test "pentool" $port_count)
    PENTOOL_RESULTS[$port_count]=$pentool_time
    echo "  Average: ${pentool_time}s"

    echo "Nmap ($port_count ports):"
    nmap_time=$(run_averaged_test "nmap" $port_count)
    NMAP_RESULTS[$port_count]=$nmap_time
    echo "  Average: ${nmap_time}s"

    ratio=$(echo "scale=2; $nmap_time / $pentool_time" | bc 2>/dev/null || echo "N/A")
    echo "  Ratio (Nmap/Pentool): ${ratio}x"

    # Update JSON
    jq --arg ports "${port_count}_ports" \
       --argjson pentool "$pentool_time" \
       --argjson nmap "$nmap_time" \
       '.volume_comparison[$ports] = {pentool: $pentool, nmap: $nmap}' \
       "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
done

# ============================================
# Print Volume Comparison Summary
# ============================================
echo ""
echo "=============================================="
echo "VOLUME COMPARISON SUMMARY"
echo "=============================================="
echo ""
printf "%-10s | %-15s | %-15s | %-10s\n" "Ports" "Pentool (s)" "Nmap (s)" "Ratio"
printf "%-10s-|-%-15s-|-%-15s-|-%-10s\n" "----------" "---------------" "---------------" "----------"
for port_count in "${PORT_COUNTS[@]}"; do
    pt=${PENTOOL_RESULTS[$port_count]}
    nt=${NMAP_RESULTS[$port_count]}
    ratio=$(echo "scale=2; $nt / $pt" | bc 2>/dev/null || echo "N/A")
    printf "%-10s | %-15s | %-15s | %-10s\n" "$port_count" "$pt" "$nt" "${ratio}x"
done

echo ""
echo "Results saved to: $RESULTS_FILE"
echo "=============================================="