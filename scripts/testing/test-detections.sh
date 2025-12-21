#!/bin/bash
# Test all custom detection rules

TESTS_PASSED=0
TESTS_FAILED=0

echo "=== Detection Rule Test Suite ==="

# Test 1: Nmap detection
echo "[TEST 1] Testing nmap detection (Rule 100001)..."
nmap -sV -p 21,22 192.168.100.20 > /dev/null 2>&1
sleep 10
# Check for alert in Wazuh
# Increment TESTS_PASSED or TESTS_FAILED

# Test 2: SSH brute force
echo "[TEST 2] Testing SSH brute force detection (Rule 100003)..."
# Run hydra with small wordlist
# Check for alert

# Final report
echo ""
echo "=== Test Results ==="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
```
