# Prerequisites

Hardware, software, and network requirements for building the purple team lab.

**Estimated Cost:** ~$100-200 (assuming you have Unraid server)  
**Skill Level:** Intermediate  
**Time Required:** 30 minutes (planning phase)

## Hardware Requirements

### Unraid Server (Minimum Specifications)

- **CPU:** 4+ cores (Intel or AMD)
- **RAM:** 16GB minimum (32GB recommended)
  - Wazuh stack: ~4-6GB
  - VMs: ~2-4GB
  - Unraid OS: ~2GB
  - Headroom for other containers
- **Storage:** 
  - 100GB+ free space for VMs
  - 50GB+ for log storage (depending on retention)
  - SSD recommended for VM storage
- **Network:** Gigabit ethernet interface

### Raspberry Pi (for Kali Linux)

- **Model:** Raspberry Pi 4 Model B
- **RAM:** 4GB minimum (8GB recommended)
- **Storage:** 64GB+ microSD card (Class 10/U3 or better)
- **Power Supply:** Official Raspberry Pi power supply or quality USB-C (3A)
- **Network:** Ethernet cable (WiFi works but wired is more reliable)
- **Optional:** Case with cooling (heatsinks or fan)

### Network Equipment

- **Router/Switch:** Managed switch with VLAN support (recommended)
- **Network Cables:** Cat5e or Cat6 ethernet cables
- **Firewall:** pfSense, OPNsense, or router with firewall capabilities

## Software Requirements

### Unraid

- **Version:** 6.9+ (tested on 6.12)
- **License:** Basic, Plus, or Pro (depending on drive count)
- **Plugins Required:**
  - Docker (included)
  - VM Manager (included)
  - Community Applications (for easy Docker deployment)

### Operating Systems to Download

**Kali Linux:**
- Download: [https://www.kali.org/get-kali/#kali-arm](https://www.kali.org/get-kali/#kali-arm)
- Version: Latest ARM64 image for Raspberry Pi 4
- Size: ~3GB compressed

**Metasploitable 2:**
- Download: [https://sourceforge.net/projects/metasploitable/](https://sourceforge.net/projects/metasploitable/)
- Version: 2.0.0
- Size: ~900MB compressed

### Docker Images (will pull automatically)

- `wazuh/wazuh-manager:4.7.0`
- `wazuh/wazuh-indexer:4.7.0`
- `wazuh/wazuh-dashboard:4.7.0`
- `graylog/graylog:5.1`
- `mongo:5.0`

## Knowledge Requirements

### Essential Skills

- **Linux command line basics:**
  - File navigation (cd, ls, pwd)
  - File editing (nano, vi, or other text editor)
  - File permissions (chmod, chown)
  - Process management (systemctl, ps)

- **Networking fundamentals:**
  - IP addressing and subnets
  - TCP/IP protocols
  - Basic firewall concepts
  - Network isolation and VLANs

- **Docker basics:**
  - Understanding containers vs VMs
  - Docker Compose files
  - Basic container management

### Helpful But Not Required

- Previous SIEM experience
- Penetration testing knowledge
- Unraid administration
- Virtualization experience

## Network Requirements

### IP Address Planning

Plan your IP allocation before starting. You'll need:

- **Static IP block:** At least 10 addresses for lab components
- **VLAN ID:** If using VLANs (e.g., VLAN 100)
- **Gateway:** Router IP for lab network
- **DNS:** Internal or external DNS servers

### Example IP Scheme
```
Lab Network: 192.168.100.0/24

192.168.100.1   - Gateway/Router
192.168.100.10  - Kali Linux (Raspberry Pi)
192.168.100.20  - Metasploitable 2
192.168.100.30  - Wazuh Manager
192.168.100.31  - Wazuh Indexer (OpenSearch)
192.168.100.32  - Wazuh Dashboard
192.168.100.40  - Graylog
192.168.100.41  - MongoDB
```

### Firewall Access

You'll need access to configure:
- VLAN creation (if using VLANs)
- Firewall rules for network isolation
- Port forwarding (optional, for remote access)

## Tools and Utilities

### On Your Main Workstation

- **SSH Client:**
  - macOS/Linux: Built-in terminal
  - Windows: PuTTY, Windows Terminal, or WSL

- **Text Editor:** 
  - VS Code (recommended)
  - Sublime Text
  - Vim/Nano

- **Image Flasher (for Raspberry Pi):**
  - balenaEtcher (recommended)
  - Raspberry Pi Imager
  - dd command (Linux/Mac)

- **VNC Viewer:**
  - For accessing VM consoles
  - RealVNC Viewer or TigerVNC

### Optional Tools

- **Network scanner:** nmap (for verification)
- **Wireshark:** For network traffic analysis
- **Git:** For managing configurations (you're already using this!)

## Pre-Installation Checklist

Before proceeding to the next steps, verify you have:

- [ ] Unraid server running with 16GB+ RAM
- [ ] 100GB+ free storage space
- [ ] Raspberry Pi 4 with power supply and microSD card
- [ ] Network equipment (switch/router with admin access)
- [ ] Downloaded Kali Linux ARM image
- [ ] Downloaded Metasploitable 2
- [ ] Planned IP address scheme
- [ ] Basic Linux and networking knowledge
- [ ] SSH access to Unraid server
- [ ] Internet connectivity for downloading Docker images

## Estimated Resource Usage

Once fully deployed, expect:

**RAM Usage:**
- Wazuh Manager: 2GB
- Wazuh Indexer (OpenSearch): 2-4GB
- Wazuh Dashboard: 512MB
- Graylog: 2GB
- MongoDB: 512MB
- Metasploitable 2 VM: 512MB-1GB
- **Total:** ~8-10GB

**Storage Usage:**
- Metasploitable 2: 8GB
- Docker volumes: 10-20GB
- Logs (30 days retention): 20-50GB
- **Total:** ~40-80GB

**CPU Usage:**
- Light load: 10-20% of 4 cores
- During scans/attacks: 40-60%
- Log processing: 20-30%

## Cost Breakdown

**If starting from scratch:**

| Item | Cost (USD) |
|------|------------|
| Raspberry Pi 4 (8GB) | $75-95 |
| MicroSD Card (64GB) | $10-15 |
| Power Supply | $8-12 |
| Ethernet Cables | $10-20 |
| **Total New Hardware** | **$103-142** |

**If you have Unraid already:**
- Software is all free/open source
- Just need Raspberry Pi and accessories

## Next Steps

Once you've verified all prerequisites:

→ Continue to [Network Setup](02-network-setup.md)

## Troubleshooting Prerequisites

**Problem: Not enough RAM on Unraid**
- Solution: Reduce JVM heap sizes in Docker Compose
- Alternative: Skip Graylog initially, just use Wazuh

**Problem: No managed switch for VLANs**
- Solution: Use physical network isolation instead
- Alternative: Accept less isolation with careful firewall rules

**Problem: Slow microSD card performance on Kali**
- Solution: Use Class 10 or UHS-1/UHS-3 rated cards
- Alternative: Boot from USB SSD (requires USB 3.0)

**Problem: Limited internet bandwidth**
- Solution: Download images on faster connection, transfer via USB
- Plan ahead: Initial Docker pulls are 2-3GB total