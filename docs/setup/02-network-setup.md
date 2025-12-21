**Current Status:** 🚧 Lab is operational on <internal-subnet> without VLAN isolation while awaiting managed switch. Attack methodology and detection techniques remain the same regardless of IP scheme.

# Network Setup

Network planning, isolation strategy, and configuration for the purple team lab.

**Time Required:** 1-2 hours  
**Difficulty:** Intermediate

## Network Architecture Overview

The lab network should be isolated from your production network while maintaining management access and internet connectivity for updates.

## Network Isolation Strategies

### Option 1: VLAN-Based Isolation (Recommended)

**Advantages:**
- Single physical network
- Flexible management
- Easy to expand
- Can route between VLANs when needed

**Requirements:**
- Managed switch with VLAN support
- Router/firewall with VLAN capabilities
- Basic understanding of VLANs

**My Implementation:**
[Describe your actual setup - e.g., "Using VLAN 100 on Unifi switch with pfSense firewall"]

### Option 2: Physical Network Isolation

**Advantages:**
- Complete isolation
- Simpler to understand
- No VLAN configuration needed

**Disadvantages:**
- Requires separate switch
- Less flexible
- More physical equipment

## IP Address Allocation

### Recommended Scheme
```
Production Network: <internal-subnet>
Lab Network:        <internal-subnet> (VLAN 100)

Lab Subnet Breakdown:
<internal-ip>    - Gateway/Router
<internal-range>  - Reserved for infrastructure

Attack Systems:
<internal-ip>   - Kali Linux (Raspberry Pi)
<internal-range> - Reserved for additional attack boxes

Target Systems:
<internal-ip>   - Metasploitable 2
<internal-range> - Reserved for additional vulnerable VMs

Detection Stack:
<internal-ip>   - Wazuh Manager
<internal-ip>   - Wazuh Indexer (OpenSearch)
<internal-ip>   - Wazuh Dashboard
<internal-ip>   - Graylog
<internal-ip>   - MongoDB

<internal-range>   - DHCP pool (optional)
<internal-range> - Reserved for expansion
```

### Document Your Scheme

Create a spreadsheet or text file tracking:
- IP address
- Hostname
- MAC address (once deployed)
- Purpose
- Static/DHCP

## VLAN Configuration

### Step 1: Create VLAN on Switch

**Example for Unifi Switch:**
1. Controller → Settings → Networks
2. Create New Network
3. Name: "Lab_Network"
4. VLAN ID: 100
5. Gateway/Subnet: <internal-subnet>
6. DHCP: Disabled (using static IPs)

**Example for pfSense:**
1. Interfaces → Assignments
2. VLANs tab → Add
3. Parent Interface: (your switch port)
4. VLAN Tag: 100
5. Description: "Lab Network"

### Step 2: Configure Switch Ports

**For Unraid server port:**
- Mode: Trunk
- Allowed VLANs: Default (1) + Lab (100)

**For Raspberry Pi port:**
- Mode: Access
- VLAN: 100

**For your workstation (management):**
- Mode: Trunk (to access both networks)
- Or: Access on default VLAN, route through firewall

## Firewall Rules

### Required Rules for Lab Operation
```
# Allow lab to internet (for updates)
Source: <internal-subnet>
Destination: any
Action: Allow
Protocol: any

# Allow management from production to lab
Source: <internal-subnet>
Destination: <internal-subnet>
Action: Allow
Protocol: TCP/UDP
Ports: 22 (SSH), 443 (HTTPS), 5900-5910 (VNC)

# Block lab to production (critical!)
Source: <internal-subnet>
Destination: <internal-subnet>
Action: Deny
Protocol: any
Log: Yes

# Allow all traffic within lab
Source: <internal-subnet>
Destination: <internal-subnet>
Action: Allow
Protocol: any
```

### pfSense Rule Example

1. Firewall → Rules → LAB_VLAN
2. Add rule (top of list):
   - Action: Block
   - Protocol: any
   - Source: LAB net
   - Destination: LAN net
   - Log: Yes
   - Description: "Block lab to production"

3. Add rule:
   - Action: Pass
   - Protocol: any
   - Source: LAB net
   - Destination: any
   - Description: "Allow lab to internet"

## Network Bridge Configuration on Unraid

### Create Custom Bridge for Lab VLAN

**Method 1: Using Unraid GUI (Easier)**

1. Settings → Network Settings
2. Enable bonding: No
3. eth0: <internal-ip> (production IP)
4. Enable br0.100 (VLAN 100)
5. br0.100 IP: <internal-ip> (Unraid management on lab network)

**Method 2: Using Network Config File**

Edit `/boot/config/network.cfg`:
```bash
# Add VLAN interface
VLAN_100="yes"
VLAN_100_ID="100"
VLAN_100_PARENT="eth0"
BRIDGE_100="br0.100"
IPADDR_100="<internal-ip>"
NETMASK_100="255.255.255.0"
```

Reboot Unraid after changes.

## Verify Network Configuration

### Test from Unraid
```bash
# SSH into Unraid
ssh root@unraid-ip

# Check interfaces
ip addr show

# Should see br0.100 with <internal-ip>

# Test connectivity
ping <internal-ip>  # Gateway
ping 8.8.8.8        # Internet
```

### Test VLAN Isolation
```bash
# From production network
ping <internal-ip>  # Should work (management allowed)

# From lab network (after setup)
ping <internal-ip>    # Should FAIL (blocked by firewall)
ping 8.8.8.8        # Should work (internet allowed)
```

## DNS Configuration

### Option 1: Use External DNS

Point all lab systems to:
- Primary: 8.8.8.8 (Google)
- Secondary: 1.1.1.1 (Cloudflare)

### Option 2: Internal DNS (Better)

If you have pfSense or Pi-hole:
- Configure DNS forwarder on gateway (<internal-ip>)
- Create local DNS entries for lab hosts
- Easier to remember: `wazuh.lab` vs `<internal-ip>`

## Remote Access Setup (Optional)

### Tailscale VPN

If you want secure remote access to the lab:
```bash
# Install on Unraid
# Community Applications → Tailscale

# Configure
1. Enable subnet routing: <internal-subnet>
2. Disable key expiry
3. Authenticate with Tailscale

# Now access lab from anywhere
```

### Port Forwarding (Less Secure)

Only if you understand the risks:
- Forward specific ports (e.g., 8443 → <internal-ip>:443 for Wazuh)
- Use strong authentication
- Consider fail2ban for SSH
- Not recommended for this lab

## Network Diagram
```
                    Internet
                        |
                   [Router/Firewall]
                        |
        +---------------+----------------+
        |                                |
   [Production]                    [Lab VLAN 100]
   <internal-subnet>                  <internal-subnet>
        |                                |
    [Workstations]              +-------+-------+
    [Home Devices]              |       |       |
                           [Unraid]  [Kali]  [Targets]
                            VMs/     RPi4    Metasploitable
                          Containers
                              |
                      [Wazuh Stack]
                      [Graylog]
```

## Troubleshooting

**Issue: Can't reach lab network from management**
```bash
# Check firewall rules allow management access
# Verify VLAN tagging on switch ports
# Check br0.100 is up on Unraid:
ip link show br0.100
```

**Issue: Lab can reach production (isolation failure)**
```bash
# Critical security issue!
# Verify firewall rules are in correct order
# Check rule is set to "block" not "reject"
# Verify source/destination subnets are correct
```

**Issue: No internet from lab**
```bash
# Check NAT is enabled on firewall for lab VLAN
# Verify DNS is configured on lab systems
# Test with: ping 8.8.8.8 (IP) vs ping google.com (DNS)
```

**Issue: Unraid can't see both networks**
```bash
# Verify trunk port configuration
# Check VLAN interface is created
# Restart networking: /etc/rc.d/rc.inet1 restart
```

## Security Considerations

**Critical: Isolate the Lab**
- Assume everything in the lab is compromised
- Never store production credentials in lab
- Don't route production traffic through lab
- Log all access from lab to production network

**Acceptable Risks in Home Lab:**
- Running deliberately vulnerable systems (isolated)
- Weak passwords for lab credentials (documented)
- Less stringent patching (it's a testing environment)

**Unacceptable Risks:**
- Lab accessing production data
- Production systems accessible from lab
- No firewall between networks
- Sharing credentials between networks

## Network Monitoring

Once setup is complete, monitor:
- Firewall logs for blocked connections
- Bandwidth usage (ensure logs aren't consuming all bandwidth)
- Failed connection attempts from lab to production

## Next Steps

Once your network is configured and tested:

→ Continue to [Unraid Configuration](03-unraid-config.md)

## Quick Reference

**Lab Network:**
- VLAN: 100
- Subnet: <internal-subnet>
- Gateway: <internal-ip>

**Key IPs:**
- Kali: .10
- Metasploitable: .20
- Wazuh: .30-.32
- Graylog: .40

**Firewall Rules:**
- ✅ Lab → Internet
- ✅ Management → Lab
- ❌ Lab → Production