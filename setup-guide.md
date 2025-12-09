# Purple Team Home Lab - Setup Guide

Complete step-by-step instructions for building an offensive and defensive security testing environment on Unraid.

**Estimated Setup Time:** 4-6 hours  
**Skill Level:** Intermediate  
**Cost:** ~$100-200 (assuming you have Unraid server)

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Network Planning](#network-planning)
3. [Unraid Configuration](#unraid-configuration)
4. [Deploy Attack Infrastructure](#deploy-attack-infrastructure)
5. [Deploy Detection Stack](#deploy-detection-stack)
6. [Configure Monitoring](#configure-monitoring)
7. [Validation and Testing](#validation-and-testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

**Unraid Server (Minimum):**
- CPU: 4+ cores
- RAM: 16GB minimum (32GB recommended)
- Storage: 100GB+ free space for VMs and logs
- Network: Gigabit ethernet

**Raspberry Pi (for Kali Linux):**
- Raspberry Pi 4 Model B (4GB or 8GB RAM)
- 64GB+ microSD card (Class 10/U3)
- Power supply
- Network cable

### Software Requirements
- Unraid 6.9+ (your current version)
- Docker and VM support enabled on Unraid
- Basic understanding of Linux command line
- SSH client for remote access

### Network Requirements
- Dedicated VLAN or network segment (recommended)
- Static IP assignments available
- Router/firewall access for network isolation

---

## Network Planning

### IP Allocation Scheme

Plan your lab network before starting. Example configuration:
```
Lab Network: 192.168.100.0/24 (adjust to your environment)

192.168.100.1   - Gateway/Router
192.168.100.10  - Kali Linux (Raspberry Pi)
192.168.100.20  - Metasploitable 2 (VM)
192.168.100.30  - Wazuh Manager
192.168.100.31  - OpenSearch
192.168.100.32  - Graylog
192.168.100.33  - MongoDB
```

### Network Isolation Strategy

**Option 1: VLAN-based (Recommended)**
- Create dedicated VLAN for lab (e.g., VLAN 100)
- Configure firewall rules: Lab → Internet allowed, Lab → Production blocked
- Allows controlled external access for updates

**Option 2: Physical Isolation**
- Separate physical switch/network
- No routing to production networks
- More secure but less flexible

**My Setup:**
[Describe your actual network setup - VLAN or physical isolation, how you configured it]

### Firewall Rules

Minimum required rules:
```
ALLOW: Lab subnet → Internet (outbound for updates)
ALLOW: Management network → Lab (for administration)
DENY:  Lab → Production networks
DENY:  Production → Lab (except management)
ALLOW: Lab internal traffic (all protocols)
```

---

## Unraid Configuration

### Enable Docker and VM Support

1. Navigate to **Settings → Docker**
2. Enable Docker: **Yes**
3. Set Docker vDisk location (ensure sufficient space)
4. Navigate to **Settings → VM Manager**
5. Enable VMs: **Yes**
6. Allocate CPU cores and RAM for VMs

### Create VM Storage

1. Navigate to **Shares**
2. Create new share: `domains` (if not exists)
3. Set appropriate permissions
4. This will store your VM disk images

### Network Bridge Configuration

Create isolated network bridge for lab:

1. Navigate to **Settings → Network Settings**
2. Create custom bridge: `br0.100` (for VLAN 100)
   - Or create separate bridge: `br1` for physical isolation
3. Note the bridge name for VM/container configuration

---

## Deploy Attack Infrastructure

### Step 1: Install Kali Linux on Raspberry Pi

**Download and Flash Kali:**
```bash
# Download Kali ARM image for Raspberry Pi 4
# From: https://www.kali.org/get-kali/#kali-arm

# Use balenaEtcher or dd to flash to microSD
# Example with dd (Linux/Mac):
sudo dd if=kali-linux-2024.x-raspberry-pi-arm64.img of=/dev/sdX bs=4M status=progress
```

**Initial Boot and Configuration:**
```bash
# Default credentials: kali/kali
# SSH into Pi after boot

# Change default password immediately
passwd

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools (if not included)
sudo apt install -y nmap metasploit-framework exploitdb
```

**Static IP Configuration:**
```bash
# Edit network configuration
sudo nano /etc/network/interfaces

# Add:
auto eth0
iface eth0 inet static
    address 192.168.100.10
    netmask 255.255.255.0
    gateway 192.168.100.1
    dns-nameservers 8.8.8.8

# Restart networking
sudo systemctl restart networking
```

### Step 2: Deploy Metasploitable 2 VM

**Download Metasploitable 2:**
```bash
# On your main workstation, download:
# https://sourceforge.net/projects/metasploitable/

# Extract the .vmdk file
unzip metasploitable-linux-2.0.0.zip
```

**Create VM on Unraid:**

1. Navigate to **VMs tab** → **Add VM**
2. Configuration:
   - **Name:** Metasploitable2
   - **CPU:** 1-2 cores
   - **RAM:** 512MB (minimum), 1GB (comfortable)
   - **OS:** Linux
   - **Machine:** Q35-6.2
   - **BIOS:** SeaBIOS
   - **Network:** Bridge br0.100 (your lab network)
   - **Network Model:** virtio

3. **Primary vDisk:**
   - Click on existing disk location
   - Upload the extracted .vmdk file to `/mnt/user/domains/`
   - Select the uploaded vmdk as primary vDisk
   - Size: 8GB (default from image)

4. **VNC/Graphics:**
   - Enable VNC for console access
   - Port: 5900 (or auto-assign)

5. **Start VM** and access via VNC

**Metasploitable 2 Initial Access:**
```bash
# Default credentials
Username: msfadmin
Password: msfadmin

# Set static IP
sudo nano /etc/network/interfaces

# Add:
auto eth0
iface eth0 inet static
    address 192.168.100.20
    netmask 255.255.255.0
    gateway 192.168.100.1

# Restart networking
sudo /etc/init.d/networking restart
```

---

## Deploy Detection Stack

### Architecture Decision

We're deploying a containerized SIEM stack using Docker Compose on Unraid. This provides:
- Easy management and updates
- Resource efficiency
- Scalability
- Reproducible configuration

### Step 1: Prepare Docker Compose Environment

**Create directory structure on Unraid:**
```bash
# SSH into Unraid
ssh root@unraid-server

# Create lab directory
mkdir -p /mnt/user/appdata/purple-lab
cd /mnt/user/appdata/purple-lab

# Create subdirectories
mkdir -p {wazuh,opensearch,graylog,mongodb}/{data,config}
```

### Step 2: Deploy Wazuh Stack

**Create Wazuh Docker Compose file:**
```bash
nano docker-compose-wazuh.yml
```
```yaml
version: '3.8'

services:
  wazuh-manager:
    image: wazuh/wazuh-manager:4.7.0
    hostname: wazuh-manager
    restart: always
    ports:
      - "1514:1514"     # Agent communication
      - "1515:1515"     # Agent enrollment
      - "514:514/udp"   # Syslog
      - "55000:55000"   # Wazuh API
    environment:
      - INDEXER_URL=https://opensearch:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecurePassword123!  # Change this
      - FILEBEAT_SSL_VERIFICATION_MODE=full
    volumes:
      - ./wazuh/config:/var/ossec/etc
      - ./wazuh/data:/var/ossec/data
    networks:
      - lab_network

  wazuh-indexer:
    image: wazuh/wazuh-indexer:4.7.0
    hostname: opensearch
    restart: always
    ports:
      - "9200:9200"
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"  # Adjust based on RAM
      - discovery.type=single-node
      - bootstrap.memory_lock=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - ./opensearch/data:/usr/share/opensearch/data
    networks:
      - lab_network

  wazuh-dashboard:
    image: wazuh/wazuh-dashboard:4.7.0
    hostname: wazuh-dashboard
    restart: always
    ports:
      - "443:5601"
    environment:
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecurePassword123!  # Match above
      - WAZUH_API_URL=https://wazuh-manager
      - API_USERNAME=wazuh-wui
      - API_PASSWORD=MyS3cr37P450r.*-  # Change this
    depends_on:
      - wazuh-indexer
    networks:
      - lab_network

networks:
  lab_network:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.100.0/24
```

**Deploy Wazuh:**
```bash
docker-compose -f docker-compose-wazuh.yml up -d

# Check logs
docker-compose -f docker-compose-wazuh.yml logs -f

# Verify containers are running
docker ps
```

**Access Wazuh Dashboard:**
- URL: `https://unraid-ip:443`
- Default credentials: `admin / SecurePassword123!` (what you set)

### Step 3: Deploy Graylog (Optional but Recommended)

Graylog provides additional log analysis capabilities and complements Wazuh.

**Create Graylog Docker Compose:**
```bash
nano docker-compose-graylog.yml
```
```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:5.0
    hostname: mongodb
    restart: always
    volumes:
      - ./mongodb/data:/data/db
    networks:
      - lab_network

  graylog:
    image: graylog/graylog:5.1
    hostname: graylog
    restart: always
    depends_on:
      - mongodb
    ports:
      - "9000:9000"     # Web interface
      - "1514:1514/udp" # Syslog UDP
      - "1514:1514/tcp" # Syslog TCP
      - "12201:12201"   # GELF
      - "12201:12201/udp"
    environment:
      - GRAYLOG_PASSWORD_SECRET=somepasswordpepper  # Change: min 16 chars
      # Password: admin / Run: echo -n "yourpassword" | shasum -a 256
      - GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918  # "admin"
      - GRAYLOG_HTTP_EXTERNAL_URI=http://192.168.100.32:9000/
      - GRAYLOG_MONGODB_URI=mongodb://mongodb:27017/graylog
    volumes:
      - ./graylog/data:/usr/share/graylog/data
      - ./graylog/config:/usr/share/graylog/config
    networks:
      - lab_network

networks:
  lab_network:
    driver: bridge
```

**Deploy Graylog:**
```bash
docker-compose -f docker-compose-graylog.yml up -d

# Access Graylog
# URL: http://unraid-ip:9000
# Credentials: admin / admin (or what you set)
```

---

## Configure Monitoring

### Step 1: Install Wazuh Agents

**On Metasploitable 2 (Target System):**
```bash
# SSH into Metasploitable
ssh msfadmin@192.168.100.20

# Download and install Wazuh agent
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_amd64.deb

sudo dpkg -i wazuh-agent_4.7.0-1_amd64.deb

# Configure agent
sudo nano /var/ossec/etc/ossec.conf

# Edit the manager IP:
<client>
  <server>
    <address>192.168.100.30</address>  # Wazuh manager IP
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>

# Start agent
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Verify connection
sudo /var/ossec/bin/agent-control -l
```

**On Kali Linux (Attacker System - Optional):**
```bash
# Similar process, but you probably want logs from attacks
# Install Wazuh agent to see your own activity
# Follow same steps as above
```

### Step 2: Configure Log Forwarding to Graylog

**On Metasploitable/monitored systems:**
```bash
# Configure rsyslog to forward to Graylog
sudo nano /etc/rsyslog.conf

# Add at end:
*.* @192.168.100.32:1514  # UDP
# Or for TCP:
*.* @@192.168.100.32:1514

# Restart rsyslog
sudo systemctl restart rsyslog
```

### Step 3: Create Basic Detection Rules

**In Wazuh Dashboard:**

1. Navigate to **Management → Rules**
2. Click **Manage rule files**
3. Create custom rule file: `local_rules.xml`

**Example custom rule for Nmap detection:**
```xml
<group name="local,syslog,">
  <rule id="100001" level="7">
    <if_sid>5710</if_sid>
    <match>nmap</match>
    <description>Nmap scan detected</description>
    <group>recon,pci_dss_11.4,</group>
  </rule>
</group>
```

4. Save and restart Wazuh manager

**In Graylog:**

1. Navigate to **System → Inputs**
2. Create Syslog UDP input on port 1514
3. Create **Streams** for different log types
4. Set up **Alerts** for specific patterns

---

## Validation and Testing

### Network Connectivity Tests

**From Kali Linux:**
```bash
# Ping test
ping -c 4 192.168.100.20  # Metasploitable
ping -c 4 192.168.100.30  # Wazuh

# Port scan test (should be detected)
nmap -sV 192.168.100.20

# Check if scan was logged
ssh root@192.168.100.30
tail -f /var/ossec/logs/alerts/alerts.log
```

### Agent Verification

**Check Wazuh agent status:**
```bash
# On Wazuh manager container
docker exec -it purple-lab-wazuh-manager-1 /bin/bash
/var/ossec/bin/agent_control -l

# Should show agents as Active
```

### Run Simple Attack Scenario

**Test 1: Nmap Scan**
```bash
# From Kali
nmap -sV 192.168.100.20

# Check Wazuh dashboard for alerts
# Should see "Nmap scan detected" if rule configured
```

**Test 2: SSH Brute Force Simulation**
```bash
# From Kali
hydra -l msfadmin -P /usr/share/wordlists/rockyou.txt ssh://192.168.100.20

# Should trigger SSH brute force alerts in Wazuh
```

**Test 3: Exploit Vulnerable Service**
```bash
# From Kali - exploit vsftpd backdoor
msfconsole
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS 192.168.100.20
exploit

# Check for exploitation alerts in Wazuh/Graylog
```

### Verify Logging Pipeline

**Check log flow:**
1. Generate activity on Metasploitable
2. Verify logs in Wazuh: **Security Events**
3. Verify logs in Graylog: **Search**
4. Confirm timestamps are current

---

## Troubleshooting

### Common Issues and Solutions

**Issue: Wazuh agents not connecting**
```bash
# Check firewall rules
sudo iptables -L -n

# Verify ports are open
netstat -tulpn | grep 1514

# Check agent logs
tail -f /var/ossec/logs/ossec.log

# Common fix: verify manager IP in agent config
```

**Issue: OpenSearch out of memory**
```bash
# Reduce heap size in docker-compose.yml
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

# Increase Docker memory limit in Unraid
# Settings → Docker → Docker memory limit
```

**Issue: High disk usage from logs**
```bash
# Configure log rotation in Wazuh
nano /var/ossec/etc/ossec.conf

# Add/modify:
<ossec_config>
  <logging>
    <log_alert_level>3</log_alert_level>  # Reduce verbosity
  </logging>
</ossec_config>

# In Graylog: System → Indices → Configure retention
```

**Issue: Container networking problems**
```bash
# Recreate Docker network
docker-compose down
docker network prune
docker-compose up -d

# Check network connectivity between containers
docker network inspect purple-lab_lab_network
```

**Issue: Unraid performance degradation**
```bash
# Check resource usage
docker stats

# Reduce SIEM resources if needed
# Stop non-essential containers during heavy operations
docker-compose stop graylog  # If not needed temporarily
```

### Performance Optimization

**For systems with limited RAM:**
- Reduce JVM heap sizes (OpenSearch, Graylog)
- Disable unnecessary Wazuh modules
- Implement aggressive log rotation
- Consider running only Wazuh (skip Graylog initially)

**For better detection:**
- Tune rule sensitivity after baseline period
- Create custom rules for your environment
- Use Wazuh's MITRE ATT&CK integration
- Set up email/webhook alerts for critical events

---

## Next Steps

Once your lab is operational:

1. **Baseline Normal Activity**
   - Let systems run for 24-48 hours
   - Document normal log patterns
   - Tune rules to reduce false positives

2. **Document Attack Scenarios**
   - Create repeatable test cases
   - Document expected detections
   - Build detection rule library

3. **Expand Capabilities**
   - Add more vulnerable VMs
   - Implement automated attack playbooks
   - Integrate with MITRE ATT&CK framework

4. **Share Your Work**
   - Update GitHub repository with findings
   - Write blog posts about specific scenarios
   - Contribute custom detection rules to community

---

## Additional Resources

- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Graylog Documentation](https://docs.graylog.org/)
- [Metasploit Unleashed](https://www.offensive-security.com/metasploit-unleashed/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)

## Support

Questions or issues? Open an issue on [GitHub](link-to-your-repo) or reach out via [gregqlewis.com](https://gregqlewis.com/contact).

---

*Last updated: December 8, 2025*