# Attack Infrastructure Setup

Deploy and configure Kali Linux and Metasploitable 2 for the purple team lab.

**Time Required:** 1-2 hours  
**Difficulty:** Intermediate

## Overview

We'll set up:
1. **Kali Linux** on Raspberry Pi 4 (attacker machine)
2. **Metasploitable 2** VM on Unraid (vulnerable target)

Both systems will be on the isolated lab network (192.168.100.0/24).

## Part 1: Kali Linux on Raspberry Pi 4

### Step 1: Download Kali Linux ARM Image

**On your workstation:**

1. Visit: https://www.kali.org/get-kali/#kali-arm
2. Download: **Kali Linux RaspberryPi 2, 3, 4 and 400 (64-Bit)**
   - File: `kali-linux-YYYY.X-raspberry-pi-arm64.img.xz`
   - Size: ~2-3GB compressed

### Step 2: Flash to MicroSD Card

**Using balenaEtcher (Recommended):**

1. Download: https://www.balena.io/etcher/
2. Install and open balenaEtcher
3. **Flash from file:** Select downloaded Kali image (.xz file)
4. **Select target:** Choose your microSD card
   - ⚠️ **WARNING:** This will erase everything on the card!
   - Verify you selected the correct device
5. **Flash!** - Takes 5-10 minutes

**Using dd (Linux/Mac Terminal):**
```bash
# Find your SD card device
# Mac:
diskutil list
# Look for /dev/diskX (where X is number)

# Linux:
lsblk
# Look for /dev/sdX

# Unmount (Mac)
diskutil unmountDisk /dev/diskX

# Flash image (adjust diskX to your device)
# Mac:
xzcat kali-linux-*.img.xz | sudo dd of=/dev/rdiskX bs=4m status=progress

# Linux:
xzcat kali-linux-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress

# This takes 10-15 minutes
# Wait for completion before removing card
```

### Step 3: Initial Boot and Configuration

1. **Insert microSD** into Raspberry Pi 4
2. **Connect ethernet cable** to lab network switch (VLAN 100 port)
3. **Connect power** - Kali will boot automatically
4. **Wait 1-2 minutes** for first boot

**Find Kali's IP address:**

Option 1 - Check router DHCP leases:
- Look for hostname: `kali`
- Note the IP address

Option 2 - Scan the network:
```bash
nmap -sn 192.168.100.0/24
# Look for Raspberry Pi Foundation MAC address
```

**SSH into Kali:**
```bash
ssh kali@192.168.100.X  # Replace X with actual IP

# Default credentials:
# Username: kali
# Password: kali
```

### Step 4: Secure and Configure Kali

**Change default password immediately:**
```bash
passwd
# Enter: kali (current password)
# Enter new strong password twice
```

**Update system:**
```bash
sudo apt update
sudo apt upgrade -y

# This takes 10-20 minutes on first run
# Grab coffee ☕
```

**Configure static IP:**
```bash
# Edit network configuration
sudo nano /etc/network/interfaces

# Replace existing eth0 config with:
auto eth0
iface eth0 inet static
    address 192.168.100.10
    netmask 255.255.255.0
    gateway 192.168.100.1
    dns-nameservers 8.8.8.8 1.1.1.1

# Save (Ctrl+X, Y, Enter)

# Apply changes
sudo systemctl restart networking

# Or reboot:
sudo reboot
```

**Reconnect with static IP:**
```bash
ssh kali@192.168.100.10
```

**Configure hostname:**
```bash
# Set hostname
sudo hostnamectl set-hostname kali-lab

# Update hosts file
sudo nano /etc/hosts

# Change line:
# 127.0.1.1 kali
# To:
127.0.1.1 kali-lab

# Save and exit
```

### Step 5: Install Additional Tools
```bash
# Essential tools (if not pre-installed)
sudo apt install -y \
    nmap \
    metasploit-framework \
    exploitdb \
    sqlmap \
    nikto \
    dirb \
    gobuster \
    john \
    hydra \
    netcat \
    tcpdump \
    wireshark \
    burpsuite

# Update Metasploit database
sudo msfdb init
sudo msfdb reinit  # if needed

# Update Exploit-DB
sudo searchsploit -u
```

**Verify installations:**
```bash
# Check versions
nmap --version
msfconsole -v
searchsploit -h
```

### Step 6: Configure SSH for Easier Access

**On your workstation, create SSH config:**
```bash
# Edit SSH config
nano ~/.ssh/config

# Add entry:
Host kali
    HostName 192.168.100.10
    User kali
    IdentityFile ~/.ssh/id_ed25519  # your SSH key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Save
```

**Copy SSH key to Kali:**
```bash
ssh-copy-id kali@192.168.100.10
# Enter password one last time
```

**Now you can connect easily:**
```bash
ssh kali
# No password needed!
```

### Step 7: Performance Tuning for Raspberry Pi

**Increase swap (helpful for intensive operations):**
```bash
# Edit swap config
sudo nano /etc/dphys-swapfile

# Change:
CONF_SWAPSIZE=100
# To:
CONF_SWAPSIZE=2048

# Restart swap service
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

**Check temperature and throttling:**
```bash
# Install monitoring tools
sudo apt install -y rpi-monitor

# Check temperature
vcgencmd measure_temp

# Should be under 80°C
# If higher, consider:
# - Active cooling (fan)
# - Better ventilation
# - Heatsinks
```

---

## Part 2: Metasploitable 2 VM on Unraid

### Step 1: Download Metasploitable 2

**On your workstation:**

1. Download from: https://sourceforge.net/projects/metasploitable/
2. File: `metasploitable-linux-2.0.0.zip`
3. Extract the ZIP file
4. You'll get: `Metasploitable.vmdk` (~900MB)

### Step 2: Upload to Unraid

**Option 1: Using Unraid Web GUI**

1. Navigate to **Shares → domains**
2. Click **Browse**
3. Create folder: `metasploitable2`
4. Upload `Metasploitable.vmdk` to this folder
   - Note: Upload may be slow (10-15 minutes on gigabit)

**Option 2: Using SCP (Faster)**
```bash
# From your workstation
scp Metasploitable.vmdk root@unraid-ip:/mnt/user/domains/metasploitable2/

# Check transfer speed
# Should see 50-100 MB/s on gigabit network
```

### Step 3: Create VM in Unraid

1. **Navigate to VMs tab**
2. **Click "Add VM"**
3. **Select Linux**

**VM Configuration:**
```
Name: Metasploitable2
Description: Intentionally vulnerable target system

CPU:
- CPUs: 1-2
- CPU Mode: host-passthrough (best performance)

Memory:
- Initial memory: 512 MB
- Max memory: 1024 MB

Machine:
- Machine: Q35-6.2 (or latest)
- BIOS: SeaBIOS

Network:
- Network Bridge: br0.100 (your lab network)
- Network Model: virtio
- MAC Address: [auto-generated - note it down]

Primary vDisk:
- Primary vDisk Location: Manual
- Path: /mnt/user/domains/metasploitable2/Metasploitable.vmdk
- Bus: IDE or SATA (VMDK doesn't support virtio)

Graphics:
- VNC: Enable
- VNC Port: 5900 (or auto-assign)

Other:
- Start VM after creation: Yes
- Autostart: No (manual start for security)
```

4. **Click "Create"**

### Step 4: Start and Access Metasploitable 2

**Start the VM:**
1. VMs tab → Metasploitable2 → **Start**
2. Wait 30-60 seconds for boot

**Access via VNC:**
1. Click **VNC** button (or icon)
2. Opens VNC console in browser

**Default credentials:**
```
Username: msfadmin
Password: msfadmin
```

### Step 5: Configure Static IP

**In Metasploitable console (via VNC):**
```bash
# Login with msfadmin/msfadmin

# Edit network configuration
sudo nano /etc/network/interfaces

# Find the eth0 section and modify:
auto eth0
iface eth0 inet static
    address 192.168.100.20
    netmask 255.255.255.0
    gateway 192.168.100.1
    dns-nameservers 8.8.8.8

# Save (Ctrl+X, Y, Enter)

# Restart networking
sudo /etc/init.d/networking restart

# Or reboot:
sudo reboot
```

**Verify from Kali:**
```bash
# SSH from Kali
ssh kali@192.168.100.10

# Ping Metasploitable
ping -c 4 192.168.100.20

# Should see replies
```

### Step 6: Verify Vulnerable Services

**From Kali, scan Metasploitable:**
```bash
# Quick scan
nmap -sV 192.168.100.20

# Full scan
nmap -sV -p- 192.168.100.20 -oN metasploitable-scan.txt
```

**Expected vulnerable services:**
```
PORT     STATE SERVICE     VERSION
21/tcp   open  ftp         vsftpd 2.3.4 (backdoor!)
22/tcp   open  ssh         OpenSSH 4.7p1
23/tcp   open  telnet      Linux telnetd
25/tcp   open  smtp        Postfix smtpd
53/tcp   open  domain      ISC BIND 9.4.2
80/tcp   open  http        Apache httpd 2.2.8
111/tcp  open  rpcbind     2 (RPC #100000)
139/tcp  open  netbios-ssn Samba smbd 3.X
445/tcp  open  netbios-ssn Samba smbd 3.X
512/tcp  open  exec        netkit-rsh rexecd
513/tcp  open  login
514/tcp  open  shell       Netkit rshd
1099/tcp open  java-rmi    Java RMI Registry
1524/tcp open  bindshell   Metasploitable root shell
2049/tcp open  nfs         2-4 (RPC #100003)
2121/tcp open  ftp         ProFTPD 1.3.1
3306/tcp open  mysql       MySQL 5.0.51a-3ubuntu5
5432/tcp open  postgresql  PostgreSQL DB 8.3.0-8.3.7
5900/tcp open  vnc         VNC (protocol 3.3)
6000/tcp open  X11         (access denied)
6667/tcp open  irc         UnrealIRCd
8009/tcp open  ajp13       Apache Jserv
8180/tcp open  http        Apache Tomcat/Coyote JSP engine 1.1
```

### Step 7: SSH Access to Metasploitable
```bash
# From Kali
ssh msfadmin@192.168.100.20
# Password: msfadmin

# You're now on Metasploitable
# DO NOT update or patch - defeats the purpose!
```

**Add to SSH config for convenience:**
```bash
# On Kali
nano ~/.ssh/config

# Add:
Host metasploitable
    HostName 192.168.100.20
    User msfadmin
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Now connect easily:
ssh metasploitable
```

## Verification Tests

### Test 1: Network Connectivity
```bash
# From Kali
ping -c 4 192.168.100.20        # Metasploitable
ping -c 4 192.168.100.30        # Where Wazuh will be
ping -c 4 8.8.8.8               # Internet
```

### Test 2: Port Scanning
```bash
# Quick vulnerability check
nmap --script vuln 192.168.100.20

# Should show multiple vulnerabilities
```

### Test 3: Exploit vsftpd Backdoor
```bash
# On Kali
msfconsole

# In Metasploit:
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS 192.168.100.20
exploit

# Should get root shell
# Type: whoami
# Should show: root
```

If this works, your attack infrastructure is ready! 🎯

## Security Considerations

**⚠️ CRITICAL WARNINGS:**

1. **Never expose Metasploitable to the internet**
   - Check firewall rules block external access
   - Verify lab network isolation

2. **Never run Metasploitable on production network**
   - Extremely vulnerable by design
   - Can be compromised in seconds

3. **Shutdown when not in use**
   - VMs tab → Metasploitable2 → Stop
   - Reduces risk of accidental exposure

4. **No sensitive data**
   - Don't store real credentials
   - Don't test with production data

5. **Document exploits**
   - Keep notes of what you compromise
   - Helps with detection rule development

## Performance Optimization

### Metasploitable VM
```bash
# If VM is slow, increase RAM:
# VMs → Metasploitable2 → Edit
# Max memory: 1024 MB → 2048 MB

# Allocate more CPU if needed:
# CPUs: 1 → 2
```

### Kali Raspberry Pi
```bash
# On Kali
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Free up resources
sudo systemctl stop bluetooth
sudo systemctl stop cups
```

## Troubleshooting

### Issue: Kali Can't Get Network Access
```bash
# Check ethernet cable connected
# Verify VLAN configuration on switch
# Check if interface is up:
ip link show eth0

# Bring up if needed:
sudo ip link set eth0 up

# Restart networking:
sudo systemctl restart networking
```

### Issue: Metasploitable Won't Boot
```bash
# Check VM logs in Unraid
cat /var/log/libvirt/qemu/Metasploitable2.log

# Common fix: Change disk bus from virtio to IDE
# VMs → Metasploitable2 → Edit
# Primary vDisk Bus: IDE
```

### Issue: Can't Connect to Metasploitable
```bash
# Verify VM is running
# Unraid → VMs tab → Check status

# Check from Unraid:
ping 192.168.100.20

# If no response, check VNC console
# Login and verify network config
```

### Issue: Exploits Not Working
```bash
# Update Metasploit on Kali
sudo msfupdate

# Verify target IP
# Verify services are running on Metasploitable:
sudo netstat -tulpn | grep LISTEN
```

## Document Your Setup

Add this to your GitHub repo:

**configs/attack-infra/system-info.md:**
```markdown
# Attack Infrastructure

## Kali Linux
- Platform: Raspberry Pi 4 (8GB)
- IP: 192.168.100.10
- Username: kali
- Kali Version: 2024.4

## Metasploitable 2
- Platform: Unraid VM
- IP: 192.168.100.20
- Username: msfadmin
- CPU: 2 cores
- RAM: 1GB
```

## Next Steps

Attack infrastructure is ready! Time to deploy the detection stack.

→ Continue to [Detection Stack Setup](05-detection-stack.md)

## Quick Reference

**Kali Commands:**
```bash
# Connect
ssh kali@192.168.100.10

# Start Metasploit
msfconsole

# Scan target
nmap -sV 192.168.100.20
```

**Metasploitable Access:**
```bash
# SSH
ssh msfadmin@192.168.100.20

# Web interface
http://192.168.100.20

# VNC (from Unraid)
VMs → Metasploitable2 → VNC
```

**Common Exploits to Test:**
- vsftpd 2.3.4 backdoor (port 21)
- UnrealIRCd backdoor (port 6667)
- Samba username map script (port 445)
- Distcc daemon (port 3632)