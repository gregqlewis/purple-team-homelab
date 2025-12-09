# Unraid Configuration

Base system configuration, Docker setup, and VM preparation for the purple team lab.

**Time Required:** 30-45 minutes  
**Difficulty:** Beginner to Intermediate

## Prerequisites

Before starting:
- [ ] Unraid server running and accessible
- [ ] Network configured (VLAN or physical isolation)
- [ ] At least 100GB free space
- [ ] SSH access to Unraid

## Initial System Checks

### Step 1: Verify System Resources
```bash
# SSH into Unraid
ssh root@your-unraid-ip

# Check available RAM
free -h

# Should show at least 16GB total
# Available should be 8GB+ before starting

# Check disk space
df -h /mnt/user/

# Check CPU
lscpu | grep "CPU(s)"
```

### Step 2: Update Unraid (if needed)

1. Navigate to **Tools → Update OS**
2. Check for updates
3. If available, backup your USB and update
4. Reboot if required

## Docker Configuration

### Step 1: Enable and Configure Docker

1. **Settings → Docker**
2. **Enable Docker:** Yes
3. **Docker vDisk location:** /mnt/user/system/docker/docker.img
4. **Docker vDisk size:** 20GB (minimum, increase if you have space)
5. **Default network type:** Custom: br0.100 (your lab network bridge)
   - Or leave as bridge and configure per-container
6. Click **Apply**

### Step 2: Install Community Applications Plugin

If not already installed:

1. **Plugins → Install Plugin**
2. Paste URL: `https://raw.githubusercontent.com/Squidly271/community.applications/master/plugins/community.applications.plg`
3. Click **Install**
4. Restart web GUI if prompted

This makes finding and installing Docker containers much easier.

### Step 3: Verify Docker is Running
```bash
# Check Docker service
docker --version

# Should show: Docker version 20.x.x or higher

# Check running containers (should be empty initially)
docker ps
```

## VM Manager Configuration

### Step 1: Enable VMs

1. **Settings → VM Manager**
2. **Enable VMs:** Yes
3. **VM storage location:** /mnt/user/domains/
4. **Allocated CPU cores:** 2-4 (leave some for Unraid and Docker)
5. **Allocated RAM:** 4-8GB (leave plenty for Docker containers)
6. Click **Apply**

### Step 2: Download VirtIO Drivers (for Windows VMs if needed later)

1. Still in VM Manager settings
2. **Download VirtIO Drivers:** Click to download
3. These help with VM performance

### Step 3: Create VM Storage Share

Verify the domains share exists:

1. **Shares → Domains**
2. If it doesn't exist, create it:
   - Name: domains
   - Primary storage: Cache (if you have cache, otherwise array)
   - Use cache: Yes (prefer)
3. Click **Apply**

## Network Bridge for Lab

### Option 1: Create Lab Bridge via GUI

1. **Settings → Network Settings**
2. Scroll to **Bridge Settings**
3. Create bridge for VLAN 100:
   - **Bridge name:** br0.100
   - **Bridge members:** eth0.100
   - **IP address:** 192.168.100.5/24
   - **Gateway:** 192.168.100.1
4. Click **Apply**
5. **Reboot** to activate

### Option 2: Create Bridge via Config File

Edit network configuration:
```bash
# Edit config
nano /boot/config/network.cfg

# Add these lines (adjust to your setup)
USE_DHCP="no"
IPADDR[0]="192.168.1.100"     # Production IP
NETMASK[0]="255.255.255.0"
GATEWAY="192.168.1.1"

# Add VLAN interface
VLAN_IFACE[0]="eth0.100"
BRIDGE[1]="br0.100"
BRIDGING="yes"
BRMEMBERS[1]="eth0.100"
IPADDR[1]="192.168.100.5"
NETMASK[1]="255.255.255.0"

# Save and reboot
reboot
```

### Verify Bridge Creation
```bash
# After reboot, check interfaces
ip addr show br0.100

# Should show:
# br0.100: <BROADCAST,MULTICAST,UP,LOWER_UP>
#     inet 192.168.100.5/24

# Test connectivity
ping 192.168.100.1  # Gateway
```

## Prepare Directory Structure

Create organized directories for the lab:
```bash
# SSH into Unraid
ssh root@unraid-ip

# Create main lab directory
mkdir -p /mnt/user/appdata/purple-lab

# Create subdirectories for each component
cd /mnt/user/appdata/purple-lab
mkdir -p wazuh/{config,data,logs}
mkdir -p opensearch/{config,data}
mkdir -p graylog/{config,data,logs}
mkdir -p mongodb/data
mkdir -p configs
mkdir -p scripts

# Set permissions
chmod -R 755 /mnt/user/appdata/purple-lab

# Verify structure
tree -L 2 /mnt/user/appdata/purple-lab
```

## Create Docker Compose Working Directory
```bash
# Create directory for docker-compose files
mkdir -p /mnt/user/appdata/purple-lab/compose

# This is where we'll put our docker-compose.yml files
cd /mnt/user/appdata/purple-lab/compose
```

## Install Useful Unraid Plugins (Optional)

### Dynamix System Temperature

Shows CPU/motherboard temperatures:

1. **Plugins → Install Plugin**
2. Search: "Dynamix System Temp"
3. Install

### CA Backup / Restore Appdata

Backup your Docker configurations:

1. **Apps → Community Applications**
2. Search: "CA Backup"
3. Install "CA Backup / Restore Appdata"

### Unraid Connect (if using Unraid 6.12+)

Easy remote access:

1. Already included in Unraid 6.12+
2. **Settings → Management Access → Unraid Connect**
3. Sign in with Unraid account

## Performance Optimization

### Adjust Docker Image Location (SSD Recommended)

If you have a cache SSD:

1. **Settings → Docker**
2. Change **Docker vDisk location** to cache drive
3. This significantly improves container performance

### Disable Unused Services
```bash
# If you're not using certain Unraid features, disable them:

# Settings → Display Settings
# Enable Local Display: No (unless you use it)

# Settings → NFS
# Enable NFS: No (unless needed)

# Settings → SMB
# Adjust settings based on actual use
```

### Set CPU Scaling Governor
```bash
# For better performance during lab operations
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# To make permanent, add to /boot/config/go file:
nano /boot/config/go

# Add this line:
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Security Hardening

### Change Default Root Password (if not already done)
```bash
passwd root
# Enter new strong password
```

### Enable SSH Key Authentication (Recommended)

From your workstation:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy to Unraid
ssh-copy-id root@unraid-ip

# Test
ssh root@unraid-ip
# Should login without password
```

### Configure SSH Settings
```bash
# Edit SSH config
nano /boot/config/ssh/sshd_config

# Recommended changes:
PermitRootLogin yes  # (needed for Unraid)
PasswordAuthentication yes  # (or no if using keys only)
PubkeyAuthentication yes
Port 22  # (or change to non-standard port)

# Restart SSH
/etc/rc.d/rc.sshd restart
```

### Set Up Automatic Backups

Configure regular backups of:
- Docker appdata
- VM configs
- Critical logs

Use "CA Backup / Restore Appdata" plugin:
1. **Plugins → CA Backup / Restore Appdata**
2. Configure backup schedule (daily/weekly)
3. Set destination (external drive or network share)

## Verify System is Ready

### Pre-deployment Checklist

Run these checks before proceeding:
```bash
# 1. Check available resources
free -h
df -h

# 2. Verify Docker is running
docker ps
docker images

# 3. Verify network bridges
ip addr show | grep br0

# 4. Check internet connectivity
ping -c 4 8.8.8.8
ping -c 4 google.com

# 5. Verify directory structure
ls -la /mnt/user/appdata/purple-lab/

# 6. Check for any array issues
cat /var/log/syslog | grep -i error
```

### Expected Results

✅ **RAM:** At least 8GB available  
✅ **Storage:** 100GB+ free  
✅ **Docker:** Service running, version 20+  
✅ **Bridges:** br0 and br0.100 (or your lab bridge) showing UP  
✅ **Internet:** Successful pings to external IPs  
✅ **Directories:** All created with correct permissions  
✅ **No Errors:** Clean syslog (or only expected warnings)  

## Common Configuration Issues

### Issue: Docker Won't Start
```bash
# Check Docker service status
/etc/rc.d/rc.docker status

# Check logs
cat /var/log/docker.log

# Common fix: Recreate Docker image
# Settings → Docker → Disable Docker → Apply
# Settings → Docker → Enable Docker → Apply
```

### Issue: VM Manager Won't Enable
```bash
# Verify CPU supports virtualization
cat /proc/cpuinfo | grep -E "vmx|svm"

# Should return lines with vmx (Intel) or svm (AMD)

# Enable in BIOS if not showing
# Look for: Intel VT-x, AMD-V, or Virtualization Technology
```

### Issue: Can't Access Lab Network
```bash
# Check VLAN interface
ip link show eth0.100

# Recreate if needed
ip link add link eth0 name eth0.100 type vlan id 100
ip link set dev eth0.100 up

# Check bridge
brctl show br0.100
```

### Issue: Low Performance
```bash
# Check if array is in parity check
cat /proc/mdcmd | grep "mdResyncPos"

# If parity check running, wait for completion
# Or pause: mdcmd set md_write_method 0

# Check disk I/O
iostat -x 1

# High %util means disk bottleneck
```

## Unraid-Specific Considerations

### Array vs Cache vs Unassigned Devices

**For lab workloads:**
- **VMs:** Cache/SSD if available (better performance)
- **Docker appdata:** Cache/SSD (much better performance)
- **Logs:** Array is fine (less I/O intensive)
- **Backups:** Array or Unassigned Device

### Share Configuration

For `/mnt/user/appdata/purple-lab`:

1. **Shares → purple-lab** (create if needed)
2. **Primary storage:** Cache
3. **Use cache:** Yes
4. **Included disks:** (leave default)
5. **Export:** No (internal use only)

This ensures Docker containers get SSD performance.

## Resource Monitoring Setup

### Install Monitoring Tools
```bash
# Install htop for better process monitoring
# Via Nerd Tools plugin:
# Apps → Community Applications → Search "Nerd Tools"
# Install and enable: htop, iotop, screen
```

### Monitor During Deployment

Keep an eye on:
```bash
# Terminal 1: CPU and RAM
htop

# Terminal 2: Disk I/O
iostat -x 2

# Terminal 3: Docker containers
watch docker stats

# Terminal 4: Logs
tail -f /var/log/syslog
```

Use `screen` or `tmux` to manage multiple terminal sessions.

## Document Your Configuration

Create a config file in your GitHub repo:

**configs/unraid/system-info.txt:**
```
Unraid Version: 6.12.6
CPU: [Your CPU model]
RAM: [Amount]GB
Cache Drive: [Size] SSD
Array: [Configuration]

Network Bridges:
- br0: 192.168.1.100 (production)
- br0.100: 192.168.100.5 (lab)

Docker vDisk: /mnt/cache/system/docker/docker.img (20GB)
VM Storage: /mnt/cache/domains/

Lab Directory: /mnt/user/appdata/purple-lab/
```

## Next Steps

Your Unraid system is now configured and ready for deployment.

→ Continue to [Attack Infrastructure Setup](04-attack-infra.md)

## Quick Reference Commands
```bash
# Check system resources
free -h && df -h

# Restart Docker
/etc/rc.d/rc.docker restart

# View Docker logs
tail -f /var/log/docker.log

# List all containers (including stopped)
docker ps -a

# Check network interfaces
ip addr show

# Monitor system
htop

# Check for errors
dmesg | grep -i error
```