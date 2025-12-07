# Purple Team Home Lab

A comprehensive offensive and defensive security testing environment built on Unraid infrastructure. This lab enables realistic attack simulations with full detection and logging capabilities.

## Architecture Overview

![Lab Architecture Diagram](images/architecture-diagram.png)

**Attack Infrastructure:**
- Kali Linux (Raspberry Pi 4) - Offensive security platform
- Metasploitable 2 (VM) - Intentionally vulnerable target system

**Detection & Logging Stack:**
- Wazuh - SIEM and threat detection
- Graylog - Log management and analysis  
- OpenSearch - Log storage and indexing
- MongoDB - Metadata storage

**Network:**
- Isolated lab network segment
- Monitored traffic flows
- Tailscale VPN for secure remote access

## Objectives

1. **Offensive Skills:** Practice penetration testing techniques in controlled environment
2. **Defensive Skills:** Develop and tune detection rules based on real attack patterns
3. **SIEM Engineering:** Build practical experience with enterprise logging infrastructure
4. **Incident Response:** Practice investigation workflows from alert to remediation

## Lab Capabilities

### Attack Simulations
- Network reconnaissance and scanning
- Vulnerability exploitation (Metasploit framework)
- Post-exploitation techniques
- Lateral movement scenarios

### Detection Engineering
- Custom Wazuh rules for attack detection
- Log correlation across multiple sources
- Alert tuning and false positive reduction
- Threat hunting queries

## Quick Start

[Link to detailed setup guide](docs/setup-guide.md)

**Prerequisites:**
- Unraid server with minimum 16GB RAM
- Raspberry Pi 4 (4GB+ recommended for Kali)
- Basic networking knowledge

**Basic Setup:**
1. Deploy Metasploitable 2 VM on Unraid
2. Install Kali Linux on Raspberry Pi 4
3. Deploy Wazuh stack using Docker Compose
4. Configure network isolation and monitoring
5. Install Wazuh agents on target systems

## Documentation

- [Architecture Details](docs/architecture.md)
- [Complete Setup Guide](docs/setup-guide.md)
- [Attack Scenarios](docs/attack-scenarios.md)
- [Detection Rules](docs/detection-rules.md)

## Key Learnings

**Technical Challenges Overcome:**
- SIEM resource optimization on consumer hardware
- Network segmentation while maintaining management access
- Log volume management and retention strategies

**Security Insights:**
- Detection patterns that work vs. generate noise
- Importance of context in alert investigation
- Balance between security monitoring and system performance

## Future Enhancements

- [ ] Additional vulnerable targets (DVWA, HackTheBox VMs)
- [ ] Automated attack playbooks
- [ ] Integration with MITRE ATT&CK framework
- [ ] Custom detection dashboard

## Blog Post

Read the full writeup: [Building a Purple Team Lab on Unraid](https://gregqlewis.com/purple-team-lab)

## Disclaimer

This lab is for educational purposes only. All attack techniques are performed in an isolated environment against systems I own and control.
