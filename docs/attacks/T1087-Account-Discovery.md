# T1087: Account Discovery

Detection validation for MITRE ATT&CK T1087 (Account Discovery) against the Ubuntu VulnLab, monitored by Wazuh. This write-up runs common local account enumeration commands on the target, traces each one to the custom Wazuh rule meant to catch it, and records where the detection holds up and where it does not.

---

## Table of Contents

- [Technique Overview](#technique-overview)
- [Lab Setup](#lab-setup)
- [Detection Objective](#detection-objective)
- [Execution](#execution)
- [Detection Analysis](#detection-analysis)
- [Findings and Gaps](#findings-and-gaps)
- [Hardening Notes](#hardening-notes)

---

## Technique Overview

**MITRE ATT&CK:** [T1087](https://attack.mitre.org/techniques/T1087/) (Account Discovery), [T1087.001](https://attack.mitre.org/techniques/T1087/001/) (Local Account)
**Tactic:** Discovery (TA0007)

After gaining a foothold, an attacker enumerates accounts to decide what to target next: which users have login shells, which belong to privileged groups such as `sudo` or `docker`, and who is logged in right now. On Linux this needs no special privileges. `/etc/passwd` is world-readable by design, and tools such as `id`, `who`, `groups`, and `getent` are on every host.

In this lab, account discovery is the step between initial access (T1110 SSH brute force) and privilege escalation. It shows the attacker the `admin`, `backup`, and `developer` accounts created by the setup script.

---

## Lab Setup

| Component | Details |
|-----------|---------|
| **Target** | Ubuntu 24.04 VulnLab VM, built by [`scripts/setup/install-all.sh`](../../scripts/setup/install-all.sh) |
| **Address** | `<vulnlab-ip>` |
| **Wazuh agent** | Installed on the VulnLab, reporting as `<vulnlab-agent>` |
| **Wazuh manager** | `<wazuh-manager-ip>` |
| **Detection rules** | 100090 and 100091 in [`configs/wazuh/local_rules.xml`](../../configs/wazuh/local_rules.xml) |
| **Access** | Interactive shell on the VulnLab as a lab user |

> **TODO:** Record the log source that carried these commands to Wazuh (for example auditd `execve` records or shell command logging). `install-all.sh` does not configure either, and the Wazuh agent does not log command execution or file reads by default. See [Findings and Gaps](#findings-and-gaps).

---

## Detection Objective

Confirm that each enumeration command produces a Wazuh alert mapped to T1087, and identify which commands go undetected.

| Rule | Level | Looks for | MITRE |
|------|-------|-----------|-------|
| **100090** | 7 | The string `/etc/passwd` anywhere in a log line | T1087.001 |
| **100091** | 7 | User enumeration command names (`w`, `who`, `users`, `id`, `groups`, `getent`) | T1087 |

---

## Execution

Each command was run on the VulnLab, then matched to the alert it produced in the Wazuh dashboard (Security Events, filtered to agent `<vulnlab-agent>`).

The **Expected rule** column is based on reading the rule patterns (see [Detection Analysis](#detection-analysis)). The **Observed** column records what Wazuh actually produced.

| # | Command | Expected rule | Observed |
|---|---------|---------------|----------|
| 1 | `cat /etc/passwd` | 100090 | _TBD_ |
| 2 | `id` | 100091 | _TBD_ |
| 3 | `who` | 100091 | _TBD_ |
| 4 | `groups` | 100091 | _TBD_ |
| 5 | `getent passwd` | 100091 | _TBD_ |

### 1. `cat /etc/passwd`

```bash
cat /etc/passwd
```

**Rule:** 100090, /etc/passwd accessed - Account Discovery (T1087.001)

**Alert:**
```json
// TODO: paste Wazuh alert JSON
```

![Wazuh alert for cat /etc/passwd](../../images/screenshots/T1087/01-cat-etc-passwd.png)

### 2. `id`

```bash
id
```

**Rule:** 100091, User enumeration command executed - Account Discovery (T1087)

**Alert:**
```json
// TODO: paste Wazuh alert JSON
```

![Wazuh alert for id](../../images/screenshots/T1087/02-id.png)

### 3. `who`

```bash
who
```

**Rule:** 100091, User enumeration command executed - Account Discovery (T1087)

**Alert:**
```json
// TODO: paste Wazuh alert JSON
```

![Wazuh alert for who](../../images/screenshots/T1087/03-who.png)

### 4. `groups`

```bash
groups
```

**Rule:** 100091, User enumeration command executed - Account Discovery (T1087)

**Alert:**
```json
// TODO: paste Wazuh alert JSON
```

![Wazuh alert for groups](../../images/screenshots/T1087/04-groups.png)

### 5. `getent passwd`

```bash
getent passwd
```

**Rule:** 100091, User enumeration command executed - Account Discovery (T1087)

**Alert:**
```json
// TODO: paste Wazuh alert JSON
```

![Wazuh alert for getent passwd](../../images/screenshots/T1087/05-getent-passwd.png)

---

## Detection Analysis

Both rules use a single `<match>` element with no parent rule (`if_sid`), decoder, or program name. Wazuh tests a `<match>` pattern against the full log line, so both rules depend on the command line or file path appearing as plain text in some log.

### Rule 100090: `/etc/passwd` access

```xml
<rule id="100090" level="7">
  <match>/etc/passwd</match>
  <description>/etc/passwd accessed - Account Discovery (T1087.001)</description>
  <mitre>
    <id>T1087.001</id>
  </mitre>
  <group>discovery,</group>
</rule>
```

- **How it matches:** The rule fires on any log line that contains the substring `/etc/passwd`. `cat /etc/passwd` matches if the command line or the opened file path is logged.
- **What it misses:** Reading the file without naming it. `getent passwd` reads `/etc/passwd` through NSS, but the command line never contains the path. Other examples are `cat /etc/pass*`, `cd /etc && cat passwd`, or `awk -F: '{print $1}' /etc/./passwd`.
- **What it over-matches:** Any log line that mentions the path, including routine activity such as `useradd`, `passwd`, package updates, and FIM events. Nothing ties the alert to a read by a user.

### Rule 100091: user enumeration commands

```xml
<rule id="100091" level="7">
  <match>w | who | users | id | groups | getent</match>
  <description>User enumeration command executed - Account Discovery (T1087)</description>
  <mitre>
    <id>T1087</id>
  </mitre>
  <group>discovery,</group>
</rule>
```

- **How it matches:** In a Wazuh `<match>` pattern, `|` separates alternatives. Spaces are not trimmed, so the spaces around each `|` are part of the pattern. The rule therefore searches for these six literal strings:

  | Alternative | Notes |
  |-------------|-------|
  | `w␣` | The letter `w` followed by a space. This matches inside ordinary words such as "new " or "show ". |
  | `␣who␣` | Needs a space on both sides |
  | `␣users␣` | Needs a space on both sides |
  | `␣id␣` | Needs a space on both sides |
  | `␣groups␣` | Needs a space on both sides |
  | `␣getent` | Needs a leading space only |

- **Effect per command:**
  - `getent passwd` is the most reliable match. ` getent` is followed by an argument, so the pattern holds whenever a space comes before it.
  - `id`, `who`, and `groups` usually run with no arguments. If the log line ends with the command, or the command name is quoted (as in auditd `a0="id"`), the trailing space is missing and the alternative does not match.
  - `w ` matches far more than the `w` command, so it can raise level-7 alerts on unrelated log lines.

> **TODO:** Fill in after reviewing the alert JSON. For each command, note which alternative matched by checking the `full_log` field, and whether the expected rule fired.

---

## Findings and Gaps

1. **No log source in the build.** `install-all.sh` does not install auditd or set up command logging, so a fresh VulnLab produces no log line for either rule to match. The detection depends on telemetry that exists outside this repo.
2. **Command matching depends on surrounding spaces (100091).** Bare `id`, `who`, and `groups` can go undetected depending on how the log source formats the command line.
3. **False positives from `w ` (100091).** The first alternative matches common text, which drowns out the real detections.
4. **Substring matching is easy to evade (100090).** Globs, relative paths, and NSS lookups all read the file without the literal string `/etc/passwd`.
5. **No parent rule or decoder.** Both rules are evaluated as top-level rules against every event. Whether they fire depends on how they interact with the stock Wazuh rules for the same log line. Test each sample line with `wazuh-logtest` to confirm.
6. **No correlation.** A single `id` and a burst of five enumeration commands in ten seconds raise the same level-7 alert. The composite rule 100100 does not include the discovery rules, so account discovery never adds to the "active intrusion" signal.
7. **MITRE granularity.** Rule 100091 maps to the parent technique T1087, but every command it targets is local account discovery (T1087.001). Its XML comment also says T1087 while the mapping says T1087.001.

---

## Hardening Notes

Account discovery cannot be prevented on Linux. `/etc/passwd` must stay world-readable for the system to work. The aim is reliable detection, not blocking.

**1. Add a defined telemetry source (auditd)**

```bash
sudo apt install -y auditd
```

```bash
# /etc/audit/rules.d/t1087.rules
-w /etc/passwd -p r -k t1087_passwd_read
-w /etc/group  -p r -k t1087_group_read
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/id     -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/who    -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/groups -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/getent -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/w      -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/users  -k t1087_enum
```

Forward the audit log to Wazuh in the agent's `ossec.conf`:

```xml
<localfile>
  <log_format>audit</log_format>
  <location>/var/log/audit/audit.log</location>
</localfile>
```

A read watch on `/etc/passwd` fires constantly, because `login`, `sshd`, `sudo`, and every NSS lookup read the file. Scope it with `-F auid>=1000 -F auid!=unset` so it only records reads by interactive users.

**2. Rewrite the rules on decoded fields instead of raw text**

The following is a proposed replacement, not yet tested in the lab:

```xml
<rule id="100090" level="7">
  <if_group>audit</if_group>
  <field name="audit.key">t1087_passwd_read</field>
  <description>/etc/passwd read by interactive user - Account Discovery (T1087.001)</description>
  <mitre><id>T1087.001</id></mitre>
  <group>discovery,</group>
</rule>

<rule id="100091" level="7">
  <if_group>audit</if_group>
  <field name="audit.key">t1087_enum</field>
  <description>User enumeration command executed: $(audit.exe) - Account Discovery (T1087.001)</description>
  <mitre><id>T1087.001</id></mitre>
  <group>discovery,</group>
</rule>
```

**3. Add a burst rule**

```xml
<rule id="100092" level="10" frequency="4" timeframe="60">
  <if_matched_group>discovery</if_matched_group>
  <same_field>audit.auid</same_field>
  <description>Multiple account discovery commands by one user in 60s (T1087.001)</description>
  <mitre><id>T1087.001</id></mitre>
  <group>discovery,</group>
</rule>
```

Then add 100092 to composite rule 100100 so discovery counts toward the intrusion chain.

**4. Reduce what discovery reveals**

- Give service accounts `/usr/sbin/nologin`, so `/etc/passwd` does not list them as login targets.
- Keep `/etc/shadow` at `640 root:shadow`. Account discovery is low impact as long as password hashes stay unreadable.
- Review membership of the `sudo` and `docker` groups. `groups` and `id` tell an attacker exactly which accounts to target next.

---

**Related:** [MITRE Mapping, T1087.001](../mitre-mapping.md#t1087001-account-discovery-local-account) · [Attack Scenarios](../attack-scenarios.md) · [Detection Rules](../../configs/wazuh/local_rules.xml)
