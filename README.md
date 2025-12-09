# Purple Team Home Lab

A comprehensive offensive and defensive security testing environment built on Unraid infrastructure. This lab enables realistic attack simulations with full detection and logging capabilities.

## Overview

This project documents the setup, configuration, and operation of a home cybersecurity lab designed for purple team operations - combining both offensive (red team) and defensive (blue team) security practices.

**Current Status:** 🚧 Documentation in progress

## Architecture

**Attack Infrastructure:**
- Kali Linux (Raspberry Pi 4) - Offensive security platform
- Metasploitable 2 (VM) - Intentionally vulnerable target system

**Detection & Logging Stack:**
- Wazuh - SIEM and threat detection
- Graylog - Log management and analysis
- OpenSearch - Log storage and indexing
- MongoDB - Metadata storage

**Infrastructure:**
- Unraid server hosting VMs and containers
- Isolated lab network segment
- Tailscale VPN for secure remote access

## Objectives

1. **Offensive Skills:** Practice penetration testing techniques in controlled environment
2. **Defensive Skills:** Develop and tune detection rules based on real attack patterns
3. **SIEM Engineering:** Build practical experience with enterprise logging infrastructure
4. **Incident Response:** Practice investigation workflows from alert to remediation

## Repository Structure
```
📁 purple-team-homelab/
├── 📄 README.md              ← You are here
├── 📁 docs/                  ← Complete documentation
│   ├── 📁 setup/             ← Step-by-step setup guides
│   └── 📄 architecture.md    ← System design overview
├── 📁 configs/               ← Configuration templates
├── 📁 scripts/               ← Automation scripts
├── 📁 images/                ← Diagrams and screenshots
└── 📁 examples/              ← Sample outputs and logs
```

## Documentation

### Setup Guides
- [Prerequisites](docs/setup/01-prerequisites.md) - Hardware, software, and network requirements
- [Network Setup](docs/setup/02-network-setup.md) - Network planning and isolation
- [Unraid Configuration](docs/setup/03-unraid-config.md) - Base system setup
- [Attack Infrastructure](docs/setup/04-attack-infra.md) - Deploy Kali and Metasploitable
- [Detection Stack](docs/setup/05-detection-stack.md) - SIEM deployment
- [Validation](docs/setup/06-validation.md) - Testing and verification

### Technical Documentation
- [Architecture Overview](docs/architecture.md) - System design and component relationships
- [Attack Scenarios](docs/attack-scenarios.md) - Documented attacks and detections
- [Detection Rules](docs/detection-rules.md) - Custom Wazuh rules
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Lessons Learned](docs/lessons-learned.md) - Key insights and takeaways

## Quick Start

Coming soon - comprehensive setup guide for building your own purple team lab.

## Lab Capabilities

### Attack Simulations
- Network reconnaissance and scanning
- Vulnerability exploitation
- Post-exploitation techniques
- Lateral movement scenarios

### Detection Engineering
- Custom Wazuh rules for attack detection
- Log correlation across multiple sources
- Alert tuning and false positive reduction
- Threat hunting queries

## Future Enhancements

- [ ] Complete documentation of all setup procedures
- [ ] Additional vulnerable targets (DVWA, HackTheBox VMs)
- [ ] Automated attack playbooks
- [ ] Integration with MITRE ATT&CK framework
- [ ] Custom detection dashboards
- [ ] Video walkthroughs of attack scenarios

## Blog

Read more about this project at [gregqlewis.com](https://gregqlewis.com)

## Disclaimer

This lab is for educational purposes only. All attack techniques are performed in an isolated environment against systems I own and control.

## License

MIT License - see [LICENSE](LICENSE) for details

## Contact

- **Blog:** [gregqlewis.com](https://gregqlewis.com)
- **LinkedIn:** [Your LinkedIn]
- **GitHub:** [@gregqlewis](https://github.com/gregqlewis)

---

*Last updated: December 2024*