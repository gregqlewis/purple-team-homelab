# Attack Scenarios

## Implemented Techniques

| Technique ID | Name | Tactic | Status | Documentation |
|--------------|------|--------|--------|---------------|
| T1087.001 | Account Discovery - Local | Discovery | ✅ Complete | [Details](./attacks/T1087-Account-Discovery.md) |
| T1003.001 | LSASS Memory Dump | Credential Access | 📋 Planned | - |

## Lab Environment
- Attacker: Kali Linux (Raspberry Pi 4)
- Target: Windows 11 VM with Sysmon
- Network: <internal-subnet>

## Execution Workflow
1. Clear baseline / note timestamp
2. Execute attack from Kali
3. Collect Sysmon logs
4. Run detection queries
5. Document findings
6. Create blog post