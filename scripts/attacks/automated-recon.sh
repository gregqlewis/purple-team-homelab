#!/bin/bash
# Automated reconnaissance and detection verification

TARGET="192.168.100.20"
RESULTS_DIR="/home/kali/attack-results"

echo "[*] Starting automated reconnaissance against $TARGET"
echo "[*] Timestamp: $(date)"

# Run nmap scan
echo "[+] Running nmap scan..."
nmap -sV -T4 $TARGET -oN $RESULTS_DIR/nmap-scan-$(date +%Y%m%d-%H%M%S).txt

# Wait for detection
sleep 30

# Check Wazuh for alerts (via API)
echo "[+] Checking Wazuh for detections..."
curl -k -u admin:password https://192.168.100.5:55000/security/alerts \
  | jq '.data.affected_items[] | select(.rule.id=="100001")'

echo "[*] Reconnaissance complete. Check results in $RESULTS_DIR"