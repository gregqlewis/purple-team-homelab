# Detection Stack Setup

Deploy and configure Wazuh SIEM, OpenSearch, and Graylog for comprehensive security monitoring.

**Time Required:** 2-3 hours  
**Difficulty:** Advanced  
**Prerequisites:** Attack infrastructure deployed and tested

## Overview

We'll deploy a multi-layered detection stack:

1. **Wazuh** - Primary SIEM for security event detection
2. **OpenSearch** - Log indexing and storage
3. **Wazuh Dashboard** - Visualization and alerting
4. **Graylog** (Optional) - Additional log analysis capabilities
5. **MongoDB** (for Graylog) - Metadata storage

## Architecture
```
Attack/Target Systems
       ↓
   Wazuh Agents
       ↓
  Wazuh Manager ←→ OpenSearch ←→ Wazuh Dashboard
       ↓
   Syslog Feed
       ↓
    Graylog ←→ MongoDB
```

## Part 1: Prepare Docker Compose Files

### Step 1: Create Working Directory
```bash
# SSH into Unraid
ssh root@unraid-ip

# Create compose directory
mkdir -p /mnt/user/appdata/purple-lab/compose
cd /mnt/user/appdata/purple-lab/compose
```

### Step 2: Create Wazuh Stack Docker Compose
```bash
nano docker-compose-wazuh.yml
```

**Paste this configuration:**
```yaml
version: '3.8'

services:
  wazuh-manager:
    image: wazuh/wazuh-manager:4.7.0
    container_name: wazuh-manager
    hostname: wazuh-manager
    restart: always
    ports:
      - "1514:1514"     # Agent communication
      - "1515:1515"     # Agent enrollment
      - "514:514/udp"   # Syslog
      - "55000:55000"   # Wazuh API
    environment:
      - INDEXER_URL=https://wazuh-indexer:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecurePassword123!
      - FILEBEAT_SSL_VERIFICATION_MODE=full
      - SSL_CERTIFICATE_AUTHORITIES=/etc/ssl/root-ca.pem
      - SSL_CERTIFICATE=/etc/ssl/filebeat.pem
      - SSL_KEY=/etc/ssl/filebeat.key
      - API_USERNAME=wazuh-wui
      - API_PASSWORD=MyS3cr37P450r.*-
    volumes:
      - wazuh_api_configuration:/var/ossec/api/configuration
      - wazuh_etc:/var/ossec/etc
      - wazuh_logs:/var/ossec/logs
      - wazuh_queue:/var/ossec/queue
      - wazuh_var_multigroups:/var/ossec/var/multigroups
      - wazuh_integrations:/var/ossec/integrations
      - wazuh_active_response:/var/ossec/active-response/bin
      - wazuh_agentless:/var/ossec/agentless
      - wazuh_wodles:/var/ossec/wodles
      - filebeat_etc:/etc/filebeat
      - filebeat_var:/var/lib/filebeat
    networks:
      wazuh_net:
        ipv4_address: 172.20.0.10

  wazuh-indexer:
    image: wazuh/wazuh-indexer:4.7.0
    container_name: wazuh-indexer
    hostname: wazuh-indexer
    restart: always
    ports:
      - "9200:9200"
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
      - "bootstrap.memory_lock=true"
      - "discovery.type=single-node"
      - "network.host=0.0.0.0"
      - "plugins.security.ssl.http.enabled=true"
      - "plugins.security.ssl.http.pemcert_filepath=/usr/share/wazuh-indexer/certs/wazuh-indexer.pem"
      - "plugins.security.ssl.http.pemkey_filepath=/usr/share/wazuh-indexer/certs/wazuh-indexer-key.pem"
      - "plugins.security.ssl.http.pemtrustedcas_filepath=/usr/share/wazuh-indexer/certs/root-ca.pem"
      - "plugins.security.allow_default_init_securityindex=true"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - wazuh-indexer-data:/var/lib/wazuh-indexer
      - ./config/wazuh_indexer_ssl_certs/root-ca.pem:/usr/share/wazuh-indexer/certs/root-ca.pem
      - ./config/wazuh_indexer_ssl_certs/wazuh-indexer-key.pem:/usr/share/wazuh-indexer/certs/wazuh-indexer-key.pem
      - ./config/wazuh_indexer_ssl_certs/wazuh-indexer.pem:/usr/share/wazuh-indexer/certs/wazuh-indexer.pem
      - ./config/wazuh_indexer_ssl_certs/admin.pem:/usr/share/wazuh-indexer/certs/admin.pem
      - ./config/wazuh_indexer_ssl_certs/admin-key.pem:/usr/share/wazuh-indexer/certs/admin-key.pem
    networks:
      wazuh_net:
        ipv4_address: 172.20.0.11

  wazuh-dashboard:
    image: wazuh/wazuh-dashboard:4.7.0
    container_name: wazuh-dashboard
    hostname: wazuh-dashboard
    restart: always
    ports:
      - "443:5601"
    environment:
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecurePassword123!
      - WAZUH_API_URL=https://wazuh-manager
      - DASHBOARD_USERNAME=kibanaserver
      - DASHBOARD_PASSWORD=kibanaserver
      - API_USERNAME=wazuh-wui
      - API_PASSWORD=MyS3cr37P450r.*-
    volumes:
      - ./config/wazuh_indexer_ssl_certs/wazuh-dashboard.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard.pem
      - ./config/wazuh_indexer_ssl_certs/wazuh-dashboard-key.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard-key.pem
      - ./config/wazuh_indexer_ssl_certs/root-ca.pem:/usr/share/wazuh-dashboard/certs/root-ca.pem
      - ./config/wazuh_dashboard/opensearch_dashboards.yml:/usr/share/wazuh-dashboard/config/opensearch_dashboards.yml
      - ./config/wazuh_dashboard/wazuh.yml:/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
    depends_on:
      - wazuh-indexer
    networks:
      wazuh_net:
        ipv4_address: 172.20.0.12

volumes:
  wazuh_api_configuration:
  wazuh_etc:
  wazuh_logs:
  wazuh_queue:
  wazuh_var_multigroups:
  wazuh_integrations:
  wazuh_active_response:
  wazuh_agentless:
  wazuh_wodles:
  filebeat_etc:
  filebeat_var:
  wazuh-indexer-data:

networks:
  wazuh_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
```

**⚠️ Important:** The above is a simplified version. For production use, Wazuh recommends using their official docker-compose generator. Let me give you the easier approach:

### Alternative: Use Wazuh's Official Docker Setup
```bash
# Download official Wazuh Docker setup
cd /mnt/user/appdata/purple-lab/
git clone https://github.com/wazuh/wazuh-docker.git
cd wazuh-docker/single-node

# Generate certificates (required)
docker-compose -f generate-indexer-certs.yml run --rm generator

# Review and customize docker-compose.yml if needed
nano docker-compose.yml

# Key changes for home lab:
# 1. Reduce memory if needed (OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m)
# 2. Change default passwords in .env file
```

### Step 3: Configure Environment Variables
```bash
# Create .env file
nano .env
```

**Add these variables:**
```bash
# Wazuh API credentials
API_USERNAME=wazuh-wui
API_PASSWORD=MySecureWazuhPassword123!

# Indexer credentials  
INDEXER_USERNAME=admin
INDEXER_PASSWORD=SecureIndexerPassword123!

# Dashboard credentials
DASHBOARD_USERNAME=kibanaserver
DASHBOARD_PASSWORD=SecureDashboardPassword123!

# Memory settings (adjust based on available RAM)
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g

# Wazuh version
WAZUH_VERSION=4.7.0
```

## Part 2: Deploy Wazuh Stack

### Step 1: Start Wazuh Services
```bash
# Make sure you're in the right directory
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node

# Start all services
docker-compose up -d

# This will take 5-10 minutes on first run
# Downloads ~2-3GB of images
```

### Step 2: Monitor Deployment
```bash
# Watch logs
docker-compose logs -f

# Wait for these messages:
# wazuh-manager: Started (pid: X)
# wazuh-indexer: Node started
# wazuh-dashboard: Server running

# Check container status
docker-compose ps

# All should show "Up" status
```

### Step 3: Verify Services are Running
```bash
# Check if services are responding
curl -k -u admin:SecureIndexerPassword123! https://localhost:9200

# Should return cluster information

# Check Wazuh API
curl -k -u wazuh-wui:MySecureWazuhPassword123! https://localhost:55000/

# Should return version info
```

### Step 4: Access Wazuh Dashboard

1. **Open browser:** `https://unraid-ip:443`
2. **Accept self-signed certificate warning**
3. **Login:**
   - Username: `admin`
   - Password: `SecureIndexerPassword123!` (from .env)
4. **You should see Wazuh dashboard!** 🎉

**Initial Dashboard Setup:**
- Skip the tutorial (or complete it)
- You'll see 0 agents - we'll add them next
- Explore the interface: Security Events, Modules, Management

## Part 3: Install Wazuh Agents

### Install Agent on Metasploitable 2
```bash
# SSH into Metasploitable
ssh msfadmin@192.168.100.20

# Download Wazuh agent for Ubuntu/Debian
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_amd64.deb

# Install
sudo dpkg -i wazuh-agent_4.7.0-1_amd64.deb

# Configure agent
sudo nano /var/ossec/etc/ossec.conf

# Find the <client> section and change:
<client>
  <server>
    <address>192.168.100.5</address>  <!-- Unraid IP on lab network -->
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>

# Save and exit

# Start and enable agent
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Check status
sudo systemctl status wazuh-agent
```

### Install Agent on Kali Linux
```bash
# SSH into Kali
ssh kali@192.168.100.10

# Download agent for Kali (Debian-based)
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_arm64.deb

# Install
sudo dpkg -i wazuh-agent_4.7.0-1_arm64.deb

# Configure (same as Metasploitable)
sudo nano /var/ossec/etc/ossec.conf

# Change server address to 192.168.100.5

# Start agent
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

### Verify Agents in Dashboard

1. **Go to Wazuh Dashboard** → **Agents**
2. Wait 1-2 minutes for agents to appear
3. You should see:
   - Metasploitable2 (or its hostname)
   - Kali-lab
4. Status should be "Active" with green indicator

**If agents don't appear:**
```bash
# On Unraid, check Wazuh manager logs
docker logs wazuh-manager | grep agent

# Verify port 1514 is open
netstat -tulpn | grep 1514

# Check firewall rules on Unraid
```

## Part 4: Configure Detection Rules

### Step 1: Access Rule Management

1. **Wazuh Dashboard** → **Management** → **Rules**
2. Click **Manage rule files**
3. **Custom rules** → `local_rules.xml`

### Step 2: Add Custom Detection Rules

Click **Edit** on `local_rules.xml` and add:
```xml
<group name="local,syslog,">
  
  <!-- Detect Nmap scans -->
  <rule id="100001" level="7">
    <if_sid>5710</if_sid>
    <match>nmap</match>
    <description>Nmap scan detected from $(srcip)</description>
    <group>recon,pci_dss_11.4,</group>
  </rule>

  <!-- Detect Metasploit usage -->
  <rule id="100002" level="10">
    <if_sid>5710</if_sid>
    <match>meterpreter|metasploit|exploit</match>
    <description>Metasploit activity detected: $(log)</description>
    <group>exploit,attack,</group>
  </rule>

  <!-- Detect SSH brute force -->
  <rule id="100003" level="10" frequency="5" timeframe="120">
    <if_matched_sid>5716</if_matched_sid>
    <same_source_ip />
    <description>SSH brute force attempt from $(srcip)</description>
    <group>authentication_failures,pci_dss_11.4,</group>
  </rule>

  <!-- Detect privilege escalation attempts -->
  <rule id="100004" level="12">
    <if_sid>5402</if_sid>
    <match>sudo|su -|pkexec</match>
    <description>Privilege escalation attempt: $(log)</description>
    <group>privilege_escalation,</group>
  </rule>

  <!-- Detect reverse shell activity -->
  <rule id="100005" level="15">
    <if_sid>5710</if_sid>
    <match>/bin/bash -i|nc -e|/bin/sh -i</match>
    <description>Reverse shell detected: $(log)</description>
    <group>exploit,backdoor,</group>
  </rule>

</group>
```

**Save** and **Restart Wazuh Manager:**
```bash
# Restart to apply rules
docker restart wazuh-manager

# Watch logs
docker logs -f wazuh-manager
```

### Step 3: Configure File Integrity Monitoring

Edit agent configuration to monitor critical directories:
```bash
# On Metasploitable
sudo nano /var/ossec/etc/ossec.conf

# Add inside <syscheck> section:
<directories check_all="yes" realtime="yes">/etc</directories>
<directories check_all="yes" realtime="yes">/bin,/sbin</directories>
<directories check_all="yes" realtime="yes">/var/www</directories>

# Restart agent
sudo systemctl restart wazuh-agent
```

## Part 5: Deploy Graylog (Optional)

Graylog provides additional log analysis and correlation capabilities.

### Step 1: Create Graylog Docker Compose
```bash
cd /mnt/user/appdata/purple-lab/compose
nano docker-compose-graylog.yml
```
```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:5.0
    container_name: graylog-mongodb
    hostname: mongodb
    restart: always
    volumes:
      - mongo_data:/data/db
    networks:
      - graylog_net

  graylog:
    image: graylog/graylog:5.1
    container_name: graylog
    hostname: graylog
    restart: always
    depends_on:
      - mongodb
    ports:
      - "9000:9000"     # Web interface
      - "1514:1514/udp" # Syslog UDP
      - "1514:1514/tcp" # Syslog TCP
      - "12201:12201"   # GELF TCP
      - "12201:12201/udp" # GELF UDP
    environment:
      # CHANGE THESE!
      - GRAYLOG_PASSWORD_SECRET=somepasswordpepper123456789012
      # Password: admin - Generate with: echo -n "yourpassword" | sha256sum
      - GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918
      - GRAYLOG_HTTP_EXTERNAL_URI=http://192.168.100.5:9000/
      - GRAYLOG_MONGODB_URI=mongodb://mongodb:27017/graylog
      - GRAYLOG_TIMEZONE=America/New_York
    volumes:
      - graylog_data:/usr/share/graylog/data
      - graylog_journal:/usr/share/graylog/data/journal
    networks:
      - graylog_net

volumes:
  mongo_data:
  graylog_data:
  graylog_journal:

networks:
  graylog_net:
    driver: bridge
```

### Step 2: Deploy Graylog
```bash
docker-compose -f docker-compose-graylog.yml up -d

# Wait 2-3 minutes for startup
docker-compose -f docker-compose-graylog.yml logs -f
```

### Step 3: Access Graylog

1. **Browser:** `http://unraid-ip:9000`
2. **Login:**
   - Username: `admin`
   - Password: `admin` (what you hashed in the compose file)

### Step 4: Configure Syslog Input

1. **System → Inputs**
2. **Select input:** Syslog UDP
3. **Launch new input**
4. **Configuration:**
   - Title: "Lab Syslog"
   - Port: 1514
   - Bind address: 0.0.0.0
5. **Save**

### Step 5: Forward Logs from Agents

**On Metasploitable and Kali:**
```bash
# Configure rsyslog to forward
sudo nano /etc/rsyslog.conf

# Add at the end:
*.* @192.168.100.5:1514

# Restart rsyslog
sudo systemctl restart rsyslog
```

**Verify in Graylog:**
1. **Search** page
2. Wait 1-2 minutes
3. You should see logs appearing

## Part 6: Performance Tuning

### Optimize for Limited Resources

**If system is slow:**
```bash
# Reduce OpenSearch heap
nano /mnt/user/appdata/purple-lab/wazuh-docker/single-node/.env

# Change:
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
# To:
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

# Restart
docker-compose restart wazuh-indexer
```

### Configure Log Retention

**Wazuh Dashboard:**
1. **Management** → **Index Management**
2. **Policies** → Create policy
3. Set retention: 30 days (adjust based on storage)

**Graylog:**
1. **System** → **Indices**
2. **Default index set** → Edit
3. **Rotation Strategy:** Time-based (daily)
4. **Retention:** Delete after 30 days

## Troubleshooting

### Issue: Wazuh containers won't start
```bash
# Check logs
docker-compose logs wazuh-manager

# Common issue: Certificate generation failed
# Solution: Re-run certificate generation
docker-compose -f generate-indexer-certs.yml run --rm generator

# Or: Not enough memory
# Check: free -h
# Reduce Java heap sizes in .env
```

### Issue: Agents not connecting
```bash
# On agent system:
sudo /var/ossec/bin/agent-control -l

# Check logs:
sudo tail -f /var/ossec/logs/ossec.log

# Common fixes:
# 1. Verify manager IP in ossec.conf
# 2. Check firewall allows port 1514
# 3. Restart agent: sudo systemctl restart wazuh-agent
```

### Issue: Dashboard not accessible
```bash
# Check container is running
docker ps | grep wazuh-dashboard

# Check logs
docker logs wazuh-dashboard

# Verify port mapping
netstat -tulpn | grep 443

# Clear browser cache and try again
```

### Issue: High resource usage
```bash
# Check resource usage
docker stats

# If OpenSearch using too much RAM:
# Reduce heap size (see Performance Tuning above)

# If disk I/O high:
# Check log retention settings
# Consider moving to SSD if on array
```

## Verification Checklist

Before proceeding, verify:

- [ ] Wazuh Dashboard accessible at https://unraid-ip:443
- [ ] Both agents showing "Active" in dashboard
- [ ] Custom rules loaded (check Management → Rules)
- [ ] File Integrity Monitoring enabled
- [ ] Graylog accessible (if deployed) at http://unraid-ip:9000
- [ ] Logs flowing into both Wazuh and Graylog
- [ ] No error messages in container logs
- [ ] System resources acceptable (RAM, CPU, disk)

## Next Steps

Detection stack is deployed and ready for testing!

→ Continue to [Validation and Testing](06-validation.md)

## Quick Reference

**Access Dashboards:**
```bash
# Wazuh
https://unraid-ip:443
User: admin
Pass: [your indexer password]

# Graylog
http://unraid-ip:9000
User: admin
Pass: admin
```

**Manage Containers:**
```bash
# View all
docker ps

# Stop all
cd /mnt/user/appdata/purple-lab/wazuh-docker/single-node
docker-compose down

# Start all
docker-compose up -d

# View logs
docker logs wazuh-manager
docker logs wazuh-indexer
docker logs wazuh-dashboard
```

**Agent Management:**
```bash
# On Unraid
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Restart agent
docker restart wazuh-manager
```