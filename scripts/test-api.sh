#!/bin/bash

# API Testing Script for Pentool
# Tests all endpoints and functionality

API_URL="http://localhost:8080"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test counter
TESTS=0
PASSED=0

run_test() {
    TESTS=$((TESTS + 1))
    local test_name="$1"
    local command="$2"
    local expected_status="$3"

    print_test "$test_name"

    response=$(eval "$command" 2>/dev/null)
    status=$?

    if [ $status -eq 0 ]; then
        PASSED=$((PASSED + 1))
        print_pass "$test_name"
        if [ -n "$response" ] && [ "$response" != "null" ]; then
            echo "$response" | jq . 2>/dev/null || echo "$response"
        fi
    else
        print_fail "$test_name"
        echo "Command: $command"
        echo "Status: $status"
    fi
    echo
}

echo "=== Pentool API Testing ==="
echo

# Test 1: Health Check
run_test "Health Check" \
    "curl -s $API_URL/health" \
    200

# Test 2: Start Scan - scanme.nmap.org
run_test "Start Scan - scanme.nmap.org" \
    "curl -s -X POST $API_URL/scan -H 'Content-Type: application/json' -d '{\"target\":\"scanme.nmap.org\"}'" \
    200

# Get the scan ID from the last response for subsequent tests
SCAN_RESPONSE=$(curl -s -X POST $API_URL/scan -H 'Content-Type: application/json' -d '{"target":"scanme.nmap.org"}')
SCAN_ID=$(echo "$SCAN_RESPONSE" | jq -r '.scan_id' 2>/dev/null)

if [ "$SCAN_ID" != "null" ] && [ -n "$SCAN_ID" ]; then
    print_info "Using scan ID: $SCAN_ID"

    # Wait a moment for scan to start
    sleep 2

    # Test 3: Get Scan Status
    run_test "Get Scan Status" \
        "curl -s $API_URL/scan/$SCAN_ID" \
        200

    # Test 4: Wait for completion and check results
    print_test "Waiting for scan completion (max 30 seconds)..."
    for i in {1..10}; do
        status_response=$(curl -s "$API_URL/scan/$SCAN_ID")
        status=$(echo "$status_response" | jq -r '.status' 2>/dev/null)

        print_info "Attempt $i: Status = $status"

        if [ "$status" = "completed" ]; then
            print_pass "Scan completed successfully"
            echo "$status_response" | jq . 2>/dev/null
            break
        elif [ "$status" = "failed" ]; then
            print_fail "Scan failed"
            echo "$status_response" | jq . 2>/dev/null
            break
        fi

        sleep 3
    done
else
    print_fail "Could not extract scan ID from response"
    echo "Response: $SCAN_RESPONSE"
fi

echo

# Test 5: Start Multiple Scans (stress test)
print_test "Multiple Concurrent Scans"
for target in "localhost" "127.0.0.1" "scanme.nmap.org"; do
    response=$(curl -s -X POST $API_URL/scan -H 'Content-Type: application/json' -d "{\"target\":\"$target\"}")
    scan_id=$(echo "$response" | jq -r '.scan_id' 2>/dev/null)
    if [ "$scan_id" != "null" ] && [ -n "$scan_id" ]; then
        print_info "Started scan for $target: $scan_id"
    else
        print_fail "Failed to start scan for $target"
    fi
done

echo

# Test 6: Invalid Requests
print_test "Invalid Request - Empty Body"
curl -s -X POST $API_URL/scan -H 'Content-Type: application/json' -d '{}' || print_info "Expected failure"

print_test "Invalid Request - Malformed JSON"
curl -s -X POST $API_URL/scan -H 'Content-Type: application/json' -d '{invalid json' || print_info "Expected failure"

print_test "Invalid Request - Non-existent Scan ID"
curl -s $API_URL/scan/non-existent-id || print_info "Expected failure"

echo

# Test 7: Database Verification
print_test "Database Verification - Recent Scans"
docker exec -i pentool-postgres psql -U admin -d pentool -c "
    SELECT COUNT(*) as total_scans FROM scans WHERE created_at > NOW() - INTERVAL '1 hour';
" 2>/dev/null || print_info "Database test skipped (not accessible)"

echo

# Summary
echo "=== Test Summary ==="
echo "Total Tests: $TESTS"
echo "Passed: $PASSED"
echo "Failed: $((TESTS - PASSED))"

if [ $PASSED -eq $TESTS ]; then
    print_pass "All tests passed! 🎉"
    exit 0
else
    print_fail "Some tests failed. Check the logs for details."
    exit 1
fi