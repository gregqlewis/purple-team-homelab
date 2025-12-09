#!/bin/bash
# Check lab health and agent status

echo "=== Purple Team Lab Health Check ==="
echo "Timestamp: $(date)"
echo ""

# Check containers
echo "[*] Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "[*] Agent Status:"
docker exec wazuh-manager /var/ossec/bin/agent_control -l

echo ""
echo "[*] System Resources:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "[*] Disk Usage:"
df -h | grep -E 'mnt|Filesystem'