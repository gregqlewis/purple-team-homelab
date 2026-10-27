# T1087: Account Discovery

Detection validation for MITRE ATT&CK T1087 (Account Discovery) against the Ubuntu VulnLab, monitored by Wazuh. This write-up runs common local account-enumeration commands on the target, traces each one to the custom Wazuh rule meant to catch it, and documents what it took to make those rules actually fire — including a detection that looked deployed but never matched a single event.

---

## Table of Contents

- [Technique Overview](#technique-overview)
- [Lab Setup](#lab-setup)
- [Detection Objective](#detection-objective)
- [Baseline: The Rules Were Blind](#baseline-the-rules-were-blind)
- [Root Cause](#root-cause)
- [Remediation](#remediation)
- [Verification](#verification)
- [Tuning: Signal vs. Noise](#tuning-signal-vs-noise)
- [Findings Summary](#findings-summary)
- [Hardening Notes](#hardening-notes)

---

## Technique Overview

**MITRE ATT&CK:** [T1087](https://attack.mitre.org/techniques/T1087/) (Account Discovery), [T1087.001](https://attack.mitre.org/techniques/T1087/001/) (Local Account)
**Tactic:** Discovery (TA0007)

After gaining a foothold, an attacker enumerates accounts to decide what to target next: which users have login shells, which belong to privileged groups such as `sudo` or `docker`, and who is logged in right now. On Linux this needs no special privileges. `/etc/passwd` is world-readable by design, and tools such as `id`, `who`, `groups`, and `getent` ship on every host.

In this lab, account discovery is the step between initial access (T1110, SSH brute force) and privilege escalation. It surfaces the `admin`, `backup`, and `developer` accounts created by the setup script.

---

## Lab Setup

| Component | Details |
|-----------|---------|
| **Target** | Ubuntu 24.04 VulnLab VM, built by [`scripts/setup/install-all.sh`](../../scripts/setup/install-all.sh) |
| **Address** | `<vulnlab-ip>` |
| **Wazuh agent** | Installed on the VulnLab, reporting as `<vulnlab-agent>` (agent 004) |
| **Wazuh manager** | `<wazuh-manager-ip>`, Wazuh v4.14.9 |
| **Telemetry** | Linux `auditd`, forwarded to Wazuh (see [`configs/audit/t1087.rules`](../../configs/audit/t1087.rules)) |
| **Detection rules** | 100090 and 100091 in [`configs/wazuh/local_rules.xml`](../../configs/wazuh/local_rules.xml) |
| **Access** | Interactive shell on the VulnLab as a lab user |

> **Note on telemetry:** `install-all.sh` does not install `auditd` or configure command logging, and the Wazuh agent does not record command execution or file reads by default. A key finding of this exercise was that the account-discovery rules had *no log source to match against* on a fresh build. Adding `auditd` was the first remediation step.

---

## Detection Objective

Confirm that local account-enumeration activity produces a Wazuh alert mapped to T1087, and identify any gap between the rules as written and the rules as deployed.

| Rule | Level | Intended signal | MITRE |
|------|-------|-----------------|-------|
| **100090** | 7 | A read of `/etc/passwd` | T1087.001 |
| **100091** | 7 | Execution of an enumeration command (`id`, `who`, `w`, `users`, `groups`, `getent`) | T1087 |

---

## Baseline: The Rules Were Blind

Before any tuning, the test commands were run on the VulnLab and the dashboard was checked for alerts on rules 100090 / 100091.

**Result: no alerts.** Two separate reasons, uncovered in order.

**1. No telemetry.** `auditd` was not installed, so nothing logged file reads or command execution:

```
$ systemctl is-active auditd
inactive          # (package not installed)
```

**2. Even with telemetry, the rule did not match.** After installing `auditd` and adding a watch on `/etc/passwd`, a real read was captured and run through `wazuh-logtest` on the manager. The event decoded correctly but hit only the base audit rule at **level 0** — no alert:

```
**Phase 2: Completed decoding.
	name: 'auditd'
	audit.key: 't1087_passwd_read'
	audit.command: 'sudo'
	...

**Phase 3: Completed filtering (rules).
	id: '80700'
	level: '0'
	description: 'Audit: Messages grouped.'
```

> *Screenshot: `images/screenshots/T1087/01-baseline-no-alerts.png` — dashboard filtered to rules 100090/100091, zero hits.*
> *Screenshot: `images/screenshots/T1087/02-logtest-before.png` — logtest showing rule 80700, level 0.*

---

## Root Cause

Three problems, from most to least obvious.

**1. Rules authored against the wrong log format.** Both rules used a bare `<match>` on raw text:

```xml
<!-- original -->
<rule id="100090" level="7">
  <match>/etc/passwd</match>
  ...
</rule>
<rule id="100091" level="7">
  <match>w | who | users | id | groups | getent</match>
  ...
</rule>
```

A `<match>` with no `if_sid` or decoder is never evaluated against decoded `auditd` events, and the filename in an audit event lives in a structured field (`audit.*`), not as the literal substring `/etc/passwd` in the line the rule inspected. The rules could only ever have matched plain command-line text in a log source that did not exist on the host.

Rule 100091 was additionally broken on its own terms: in a Wazuh `<match>`, `|` separates alternatives and surrounding spaces are literal, so it searched for `"w "`, `" who "`, `" id "`, etc. A bare `id` at end of line, or auditd's `a0="id"`, has no trailing space and would not match — while `"w "` matches ordinary words like `"new "`, generating false positives.

**2. The deployed ruleset had drifted from source control.** Comparing the live manager to the repo:

```
$ grep -oE 'rule id="[0-9]+"' /var/ossec/etc/rules/local_rules.xml | sort -u
100010  100020  100030  100050  100060  100090  100100  100101  100102
```

- The repo tracks **25** custom rules; only **9** were live.
- Rule **100091** — one of the two rules under test — **was never deployed at all.**
- Two live rules (**100101**, **100102**) exist nowhere in the repo; they are AWS CloudTrail rules belonging to a separate cloud-detection lab, chained under a locally-redefined 100100.
- There was no pipeline keeping source control and the running manager in sync.

> *Screenshot: `images/screenshots/T1087/03-rule-drift.png` — live rule inventory vs. repo.*

**3. No telemetry in the build** (as above): the repo's own install script provisions nothing for these rules to consume.

---

## Remediation

**Step 1 — Add a defined telemetry source.** Install `auditd` on the target and watch the relevant activity. See [`configs/audit/t1087.rules`](../../configs/audit/t1087.rules):

```
# /etc/audit/rules.d/t1087.rules
-w /etc/passwd -p r -k t1087_passwd_read
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/id      -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/getent  -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/who     -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/w       -k t1087_enum
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/groups  -k t1087_enum
```

Forward the audit log to Wazuh in the agent's `ossec.conf`:

```xml
<localfile>
  <log_format>audit</log_format>
  <location>/var/log/audit/audit.log</location>
</localfile>
```

**Step 2 — Rewrite the rules against decoded fields.** Instead of matching raw text, chain to the audit base rule (80700) and match the `audit.key` the watch sets. See [`configs/wazuh/local_rules.xml`](../../configs/wazuh/local_rules.xml):

```xml
<!-- Detect /etc/passwd Access via auditd (T1087.001) -->
<rule id="100090" level="7">
  <if_sid>80700</if_sid>
  <field name="audit.key">t1087_passwd_read</field>
  <description>/etc/passwd accessed - Account Discovery (T1087.001)</description>
  <mitre><id>T1087.001</id></mitre>
  <group>discovery,pci_dss_10.2.1,</group>
</rule>

<!-- Detect User Enumeration Commands via auditd (T1087) -->
<rule id="100091" level="7">
  <if_sid>80700</if_sid>
  <field name="audit.key">t1087_enum</field>
  <description>User enumeration command executed - Account Discovery (T1087)</description>
  <mitre><id>T1087</id></mitre>
  <group>discovery,</group>
</rule>
```

Because the `auditd` rules scope `t1087_enum` to specific binaries, the Wazuh rule needs only the key as its signal — the audit layer does the filtering.

---

## Verification

After deploying the telemetry and the corrected rules, the same audit events were re-tested in `wazuh-logtest`.

**Rule 100090 — `/etc/passwd` read:**
```
**Phase 3: Completed filtering (rules).
	id: '100090'
	level: '7'
	description: '/etc/passwd accessed - Account Discovery (T1087.001)'
	mitre.id: '['T1087.001']'
	mitre.tactic: '['Discovery']'
	mitre.technique: '['Local Account']'
**Alert to be generated.
```

**Rule 100091 — enumeration command (`id`):**
```
**Phase 2: Completed decoding.
	audit.command: 'id'
	audit.exe: '/usr/bin/id'
	audit.key: 't1087_enum'

**Phase 3: Completed filtering (rules).
	id: '100091'
	level: '7'
	description: 'User enumeration command executed - Account Discovery (T1087)'
	mitre.id: '['T1087']'
**Alert to be generated.
```

Both flipped from **80700 / level 0 (no alert)** to **level-7 alerts with correct MITRE mappings**. Running `cat /etc/passwd` and `id` on the VulnLab then produced live alerts in the dashboard, confirming the full pipeline: command → `auditd` → agent → manager → alert.

> *Screenshot: `images/screenshots/T1087/04-logtest-after.png` — logtest showing 100090/100091 at level 7.*
> *Screenshot: `images/screenshots/T1087/05-dashboard-alerts.png` — live 100090 and 100091 alerts for agent `<vulnlab-agent>`.*

---

## Tuning: Signal vs. Noise

The detection worked, but the initial audit configuration was far too noisy:

- A broad `execve` audit rule (`-S execve` with no `-F exe=`) logged **every command on the host**, flooding the pipeline.
- The `-p r` watch on `/etc/passwd` fires on **every read by every process** — `sudo`, PAM, and NSS lookups all read it constantly. One `cat /etc/passwd` was buried among thousands of routine reads; the dashboard showed **~9,000 events** in the window, dominated by 100090.

Tuning applied:
- **Enumeration:** narrowed the audit rule from catch-all `execve` to specific binaries (`id`, `getent`, `who`, `w`, `groups`) under key `t1087_enum`. Noise from unrelated commands disappears at the source, before it reaches Wazuh.
- **`/etc/passwd` reads:** inherently noisy. File-read auditing on a hot file cannot be made quiet. In production, prefer detecting *command-line access* to the file (an `execve` of `cat`/`less`/`grep` with an `/etc/passwd` argument) over raw read auditing, or scope the watch to interactive users with `-F auid>=1000 -F auid!=unset`.

> *Screenshot (optional): `images/screenshots/T1087/06-noise.png` — event volume before/after tuning.*

---

## Findings Summary

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Account-discovery rules had no telemetry source on a fresh build (`auditd` absent) | High | Fixed |
| 2 | Rules authored against raw text, never matched decoded `auditd` events | High | Fixed |
| 3 | Rule 100091 was never deployed to the manager | High | Fixed |
| 4 | Deployed ruleset drifted from source control (9 of 25 rules live; 2 untracked rules from another lab); no sync pipeline | Medium | Documented |
| 5 | `/etc/passwd` read auditing is inherently high-volume | Low | Tuned / accepted |
| 6 | 100091 maps to parent T1087; its targets are all T1087.001 (local account) | Low | Noted |

The headline lesson: **a detection rule that exists in source control, is mapped to a technique, and appears in the SIEM can still catch nothing.** Only validation against real telemetry proves a detection works.

---

## Hardening Notes

Account discovery cannot be prevented on Linux — `/etc/passwd` must stay world-readable. The goal is reliable, low-noise detection.

**Add a burst/correlation rule** so a flurry of enumeration counts as more than isolated events:

```xml
<rule id="100092" level="10" frequency="4" timeframe="60">
  <if_matched_group>discovery</if_matched_group>
  <same_field>audit.auid</same_field>
  <description>Multiple account-discovery commands by one user in 60s (T1087)</description>
  <mitre><id>T1087</id></mitre>
  <group>discovery,</group>
</rule>
```
Then add 100092 to the composite intrusion rule so discovery contributes to the "active intrusion" signal.

**Establish a deployment pipeline.** The drift in Finding #4 is the real operational gap. The version-controlled `local_rules.xml` should be the single source of truth, deployed to the manager by a repeatable process, with a check that the live ruleset matches the repo.

**Reduce what discovery reveals.** Give service accounts `/usr/sbin/nologin` so they are not listed as login targets; keep `/etc/shadow` at `640 root:shadow`; and review `sudo`/`docker` group membership, since `id` and `groups` hand an attacker a target list.

---

**Related:** [MITRE Mapping, T1087.001](../mitre-mapping.md#t1087001-account-discovery-local-account) · [Attack Scenarios](../attack-scenarios.md) · [Detection Rules](../../configs/wazuh/local_rules.xml) · [Audit Rules](../../configs/audit/t1087.rules)
