# T1087 - Account Discovery

**MITRE ATT&CK:** [T1087.001 - Local Account](https://attack.mitre.org/techniques/T1087/001/)

**Date:** December 20, 2025  
**Lab Environment:**
- **Attacker:** 192.168.8.95 (Raspberry Pi 4 - Kali Linux)
- **Target:** 192.168.8.18 (Windows 11 VM - Unraid)
- **Detection:** Sysmon v15.x + Windows Security Auditing

## Executive Summary

Account discovery allows attackers to enumerate user accounts on systems, providing reconnaissance data for lateral movement and privilege escalation. This lab demonstrates SMB-based enumeration techniques and explores detection challenges in resource-constrained home lab environments.

## Technique Overview

**Tactic:** Discovery  
**Platform:** Windows  
**Data Sources:** Process monitoring, network traffic, authentication logs  
**Defenses Bypassed:** None (reconnaissance is inherently passive)

### Attack Workflow
1. External attacker scans for open SMB ports (445, 139)
2. Attempts anonymous or authenticated enumeration
3. Retrieves list of local and domain user accounts
4. Uses information for targeted attacks

## Lab Environment

### Attack Platform
- Raspberry Pi 4 (4GB RAM)
- Kali Linux 2024.x
- Tools: enum4linux, nmap

### Target System
- Windows 11 Pro VM (4GB RAM, 2 vCPU)
- Sysmon 15.x with SwiftOnSecurity configuration
- Windows Security Auditing enabled

### Network
- Shared subnet: 192.168.8.0/24 (VLAN isolation pending)
- No network segmentation (future homelab enhancement)

## Attack Execution

### Reconnaissance
```bash
# Port scan to identify SMB
nmap -p 445 192.168.8.18
# Result: Port 445/tcp open (microsoft-ds)
```

### Enumeration - enum4linux
```bash
enum4linux -U 192.168.8.18
```

**Results:**
- **RID Range:** 500-550, 1000-1050
- **Known Usernames:** administrator, guest, krbtgt, domain admins, root, bin, none
- **Enumeration Status:** Partial success (anonymous access limited)
- **Workgroup/Domain:** Could not enumerate (access denied)

### Enumeration - nmap
```bash
sudo nmap -p 445 --script smb-enum-users 192.168.8.18
```

**Results:**
- Port 445: open
- Service: microsoft-ds
- Enumeration: Limited by authentication requirements

## Detection Analysis

### Initial Challenge: Configuration Matters

**Problem:** Initial testing showed zero detection despite successful attack execution.

**Root Causes Identified:**
1. **Sysmon Configuration:** SwiftOnSecurity config only logged specific suspicious ports
   - Port 445 (SMB) was not in the monitored port list
   - Solution: Added port 445 to NetworkConnect include rules
   
2. **Windows Firewall:** Blocked SMB from external network
   - Attack traffic filtered before reaching SMB service
   - Solution: Enabled firewall rule for lab subnet (192.168.8.0/24)
   
3. **Security Auditing:** Windows Security event logging disabled by default
   - No authentication or connection events logged
   - Solution: Enabled audit policies via `auditpol`

### Detection Methods

#### Sysmon (Limited Effectiveness)

**Event ID 3 (Network Connection):**
- Logs **outbound** connections initiated by local processes
- Does NOT capture inbound connections to listening services
- **Limitation:** External SMB enumeration invisible to Sysmon Event ID 3

**Event ID 1 (Process Creation):**
- Would detect local enumeration tools (net.exe, PowerShell)
- Not triggered by external network-based enumeration

**Conclusion:** Sysmon alone insufficient for detecting external reconnaissance.

#### Windows Security Logs (Primary Detection)

After enabling audit policies:

**Event ID 5156 (Windows Filtering Platform):**
- Logs allowed/blocked connection attempts
- Should capture source IP, destination port, protocol
- **Status:** Enabled but requires further tuning for reliable SMB detection

**Event ID 4624 (Successful Logon):**
- Tracks successful authentication attempts
- Useful for detecting valid credential usage

**Event ID 4625 (Failed Logon):**
- Tracks failed authentication attempts
- Critical for detecting brute force and enumeration
- **Status:** No events (anonymous enumeration didn't trigger authentication)

### Detection Queries

See: [T1087-Detection-Queries.ps1](../../scripts/monitoring/T1087-Detection-Queries.ps1)

**Key Indicators to Monitor:**
- Network connections to ports 445, 139 from unexpected sources
- Multiple connection attempts in short timeframe
- Authentication failures from external IPs
- Process creation of enumeration tools (net.exe, dsquery.exe, PowerShell Get-LocalUser)

## Lessons Learned

### 1. Detection Requires Configuration, Not Just Tools

Installing Sysmon doesn't automatically provide detection. Effective monitoring requires:
- Understanding what each tool actually logs
- Configuring audit policies appropriately
- Combining multiple log sources
- Testing and validating detection coverage

### 2. Tool Limitations Must Be Understood

**Sysmon Event ID 3:**
- Designed for outbound connection monitoring
- Useful for detecting malware C2 and data exfiltration
- Ineffective for detecting inbound reconnaissance

**Windows Security Logs:**
- Disabled by default (performance considerations)
- Essential for authentication and network monitoring
- Must be explicitly enabled and configured

### 3. Multi-Layered Detection is Essential

Relying on a single log source creates blind spots. Effective detection requires:
- **Network layer:** Firewall logs, NetFlow, IDS
- **Host layer:** Sysmon, Windows Security, application logs
- **Authentication layer:** Domain controller logs, failed logons
- **Correlation:** Combine signals across sources

### 4. Lab Constraints Reflect Reality

**Resource Limitations:**
- 8GB RAM total limited comprehensive SIEM deployment
- Chose Sysmon + Windows Security over full detection stack
- **Real-world parallel:** Budget and resource constraints exist in production

**Configuration Gaps:**
- Default Windows settings prioritize performance over logging
- **Real-world parallel:** Many organizations run with default configs

## Mitigation Recommendations

### Network Controls
- Restrict SMB (445/139) to internal networks only
- Implement network segmentation (VLANs)
- Use firewall rules to limit SMB access by source IP

### Authentication Hardening
- Disable anonymous SMB access
- Require authentication for all SMB operations
- Implement SMB signing

### Monitoring & Detection
- Enable Windows Security audit policies
- Monitor Event IDs: 4624, 4625, 5156
- Alert on repeated connection attempts to SMB ports
- Baseline normal SMB traffic patterns

### Host Hardening
- Keep systems patched
- Disable unnecessary services
- Use least privilege principles
- Enable Credential Guard (Windows 11 Pro+)

## Cloud Security Context

In AWS/Azure environments, similar enumeration occurs via:

**AWS:**
- `aws iam list-users` - enumerate IAM users
- `aws s3 ls` - bucket enumeration
- EC2 instance metadata queries

**Detection:**
- CloudTrail logs API calls
- Look for reconnaissance patterns (List*, Describe*, Get* operations)
- Monitor for unfamiliar source IPs/user agents

**Defense:**
- Least privilege IAM policies
- MFA enforcement
- CloudTrail + GuardDuty for detection

## Repository Files

**Attack Commands:** [scripts/attacks/T1087-enum-accounts.sh](../../scripts/attacks/T1087-enum-accounts.sh)  
**Detection Queries:** [scripts/monitoring/T1087-Detection-Queries.ps1](../../scripts/monitoring/T1087-Detection-Queries.ps1)  
**Attack Logs:** [examples/logs/T1087/](../../examples/logs/T1087/)  
**Screenshots:** [images/screenshots/T1087/](../../images/screenshots/T1087/)

## Screenshots

1. [Attack Execution - enum4linux](../../images/screenshots/T1087/attack-enum4linux.png)
2. [Attack Execution - nmap](../../images/screenshots/T1087/attack-nmap.png)
3. [Configuration Troubleshooting](../../images/screenshots/T1087/troubleshooting.png)

## References

- [MITRE ATT&CK T1087](https://attack.mitre.org/techniques/T1087/)
- [Microsoft Sysmon Documentation](https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon)
- [SwiftOnSecurity Sysmon Config](https://github.com/SwiftOnSecurity/sysmon-config)
- [Windows Security Auditing](https://docs.microsoft.com/en-us/windows/security/threat-protection/auditing/auditing-security-event-categories)

## Blog Post

Full writeup with detailed analysis: [gregqlewis.com - Detecting Account Discovery in the Purple Team Home Lab](https://gregqlewis.com)

---

**Author:** Greg Lewis  
**Lab:** Purple Team Home Lab  
**Date:** December 20, 2025