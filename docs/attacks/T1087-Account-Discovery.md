# T1087 - Account Discovery

**MITRE ATT&CK:** [T1087.001 - Local Account](https://attack.mitre.org/techniques/T1087/001/)

**Date:** December 20, 2025  
**Lab Environment:** Windows 11 VM + Kali Pi

## Overview
Account discovery allows attackers to enumerate user accounts on a system or domain, providing reconnaissance data for lateral movement and privilege escalation.

## Lab Setup
- **Attacker:** Raspberry Pi 4 (Kali Linux) - 192.168.8.95
- **Target:** Windows 11 VM - 192.168.8.18
- **Detection:** Sysmon v15.x

## Attack Execution

### Commands Used
```bash
# enum4linux - Anonymous SMB enumeration
enum4linux -U 192.168.8.18

# nmap NSE script
nmap -p 445 --script smb-enum-users 192.168.8.18
```

See [attack script](../../scripts/attacks/T1087-enum-accounts.sh) for full commands.

## Detection

### Sysmon Event IDs
- **Event ID 3:** Network connection to SMB (port 445)
- **Event ID 1:** Process creation (if local enumeration occurs)

### Detection Queries
See [T1087-Detection-Queries.ps1](../../scripts/monitoring/T1087-Detection-Queries.ps1)

## Key Findings
1. Network connections to port 445 indicate SMB enumeration
2. External IP addresses connecting to SMB require investigation
3. Command-line logging captures local enumeration tools
4. Baseline understanding of normal SMB traffic is essential

## Screenshots
![Attack Execution](../../images/screenshots/T1087/02-attack-execution.png)
![Network Detection](../../images/screenshots/T1087/03-detection.png)

## Mitigation
- Restrict SMB access to trusted networks only
- Enable SMB signing
- Monitor Event ID 3 for unusual SMB connections
- Implement network segmentation

## Cloud Security Context
In AWS environments, similar enumeration occurs via:
- IAM user listing (`aws iam list-users`)
- S3 bucket enumeration
- EC2 instance metadata queries

Detection strategy: Monitor CloudTrail for reconnaissance API calls.

## References
- [MITRE ATT&CK T1087](https://attack.mitre.org/techniques/T1087/)
- [Microsoft Sysmon Documentation](https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon)

## Blog Post
Full writeup: [gregqlewis.com/blog/t1087-account-discovery](https://gregqlewis.com)