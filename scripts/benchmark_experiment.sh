#!/bin/bash

# Extended Experiments for Scientific Paper
# Tests Pentool vs Nmap performance at various port ranges
# Measures actual scan duration from scanner agent logs

set -e

# Configuration
TARGET="scanme.nmap.org"
RUNS=3
OUTPUT_DIR="experiment_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCANNER_LOG="/tmp/scanner-agent.log"

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
generate_ports_json() {
    local count=$1
    seq 1 "$count" | jq -s '.'
}

# Function to extract duration from scanner log
get_last_scan_duration() {
    # Get duration from last scan completed message
    tail -20 "$SCANNER_LOG" | grep "Completed port scan" | tail -1 | jq -r '.duration' 2>/dev/null || echo "0"
}

# Function to measure Pentool scan time using real HTTP request timing
run_pentool_scan() {
    local port_count=$1
    local ports_json=$(generate_ports_json $port_count)

    # Mark log position before scan
    local log_lines_before=$(wc -l < "$SCANNER_LOG" 2>/dev/null || echo 0)

    # Start timing from request
    local start_ns=$(date +%s%N)

    # Submit scan request
    local response=$(curl -s -X POST http://localhost:8080/scan \
        -H "Content-Type: application/json" \
        -d "{\"target\":\"$TARGET\",\"ports\":$ports_json}")

    local scan_id=$(echo "$response" | jq -r '.id')

    if [ -z "$scan_id" ] || [ "$scan_id" = "null" ]; then
        echo "ERROR"
        return 1
    fi

    # Wait for scanner to complete by monitoring log
    local max_wait=600  # 10 minutes max
    local waited=0
    local scan_completed=false

    while [ "$scan_completed" = "false" ] && [ $waited -lt $max_wait ]; do
        sleep 0.1
        waited=$((waited + 1))

        # Check if scanner completed this scan
        if tail -50 "$SCANNER_LOG" | grep -q "\"id\":\"$scan_id\".*Completed port scan"; then
            scan_completed=true
        fi
    done

    local end_ns=$(date +%s%N)

    if [ "$scan_completed" = "false" ]; then
        echo "TIMEOUT"
        return 1
    fi

    # Calculate duration in seconds
    local duration_ns=$((end_ns - start_ns))
    local duration_sec=$(echo "scale=3; $duration_ns / 1000000000" | bc)

    echo "$duration_sec"
}

# Function to measure Nmap scan time
run_nmap_scan() {
    local port_count=$1

    # Use high performance options
    local start_ns=$(date +%s%N)
    nmap -p 1-$port_count -T4 --min-parallelism 100 --max-retries 1 "$TARGET" > /dev/null 2>&1
    local end_ns=$(date +%s%N)

    local duration_ns=$((end_ns - start_ns))
    local duration_sec=$(echo "scale=3; $duration_ns / 1000000000" | bc)

    echo "$duration_sec"
}

# Function to run multiple tests and get average/min/max
run_averaged_test() {
    local tool=$1
    local port_count=$2

    local times=()
    local total=0
    local min=999999
    local max=0

    for ((run=1; run<=RUNS; run++)); do
        echo -n "  Run $run/$RUNS: "

        if [ "$tool" = "pentool" ]; then
            local time_val=$(run_pentool_scan $port_count)
        else
            local time_val=$(run_nmap_scan $port_count)
        fi

        if [ "$time_val" = "ERROR" ] || [ "$time_val" = "TIMEOUT" ]; then
            echo "FAILED"
            continue
        fi

        echo "${time_val}s"
        times+=("$time_val")
        total=$(echo "$total + $time_val" | bc)

        # Track min/max
        if (( $(echo "$time_val < $min" | bc -l) )); then
            min=$time_val
        fi
        if (( $(echo "$time_val > $max" | bc -l) )); then
            max=$time_val
        fi

        # Brief pause between runs
        sleep 2
    done

    if [ ${#times[@]} -eq 0 ]; then
        echo "0"
        return 1
    fi

    local average=$(echo "scale=3; $total / ${#times[@]}" | bc)
    echo "$average"
}

# Collect environment info
echo ""
echo "Collecting environment information..."
OS_INFO=$(lsb_release -d 2>/dev/null | cut -f2 || uname -a)
GO_VERSION=$(go version | awk '{print $3}')
CPU_INFO=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || echo "Unknown")
RAM_INFO=$(free -h | grep Mem | awk '{print $2}')
NMAP_VERSION=$(nmap --version | head -1)

echo "  OS: $OS_INFO"
echo "  Go: $GO_VERSION"
echo "  CPU: $CPU_INFO"
echo "  RAM: $RAM_INFO"
echo "  Nmap: $NMAP_VERSION"

# Initialize JSON results
cat > "$RESULTS_FILE" << EOF
{
  "experiment_date": "$(date +%Y-%m-%d)",
  "environment": {
    "os": "$OS_INFO",
    "go_version": "$GO_VERSION",
    "cpu": "$CPU_INFO",
    "ram": "$RAM_INFO",
    "nmap_version": "$NMAP_VERSION"
  },
  "volume_comparison": {},
  "scalability": {},
  "break_even_point": {},
  "observations": []
}
EOF

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

    if [ "$pentool_time" != "0" ] && [ "$nmap_time" != "0" ]; then
        ratio=$(echo "scale=2; $pentool_time / $nmap_time" | bc 2>/dev/null || echo "N/A")
        speedup=$(echo "scale=2; $nmap_time / $pentool_time" | bc 2>/dev/null || echo "N/A")
        echo "  Pentool/Nmap ratio: ${ratio}x"
        echo "  Nmap/Pentool speedup: ${speedup}x"
    fi

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
printf "%-10s | %-15s | %-15s | %-15s\n" "Ports" "Pentool (s)" "Nmap (s)" "Speedup"
printf "%-10s-|-%-15s-|-%-15s-|-%-15s\n" "----------" "---------------" "---------------" "---------------"
for port_count in "${PORT_COUNTS[@]}"; do
    pt=${PENTOOL_RESULTS[$port_count]}
    nt=${NMAP_RESULTS[$port_count]}
    if [ "$pt" != "0" ] && [ "$nt" != "0" ]; then
        speedup=$(echo "scale=2; $nt / $pt" | bc 2>/dev/null || echo "N/A")
    else
        speedup="N/A"
    fi
    printf "%-10s | %-15s | %-15s | %-15s\n" "$port_count" "$pt" "$nt" "${speedup}x"
done

echo ""
echo "Results saved to: $RESULTS_FILE"
echo "=============================================="
echo ""
cat "$RESULTS_FILE" | jq .