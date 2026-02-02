#!/bin/bash
#
# Purple Team Lab - Automated Installation Script
# Author: Greg Lewis
# Website: https://gregqlewis.com
# WARNING: This creates an intentionally vulnerable system
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              PURPLE TEAM LAB INSTALLATION                     ║
║                                                               ║
║  WARNING: This creates an INTENTIONALLY VULNERABLE system     ║
║  NEVER deploy on production or internet-facing networks       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

read -p "Do you understand the risks and wish to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled."
    exit 1
fi

log() {
    echo -e "${GREEN}[+]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[-]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root or with sudo"
    exit 1
fi

log "Starting Purple Team Lab installation..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install base packages
log "Installing base packages..."
apt install -y \
    net-tools \
    curl \
    wget \
    vim \
    git \
    docker.io \
    docker-compose \
    mysql-server \
    postgresql \
    apache2 \
    php \
    php-mysql \
    openssh-server \
    vsftpd \
    samba \
    nfs-kernel-server \
    unzip \
    hydra \
    nmap

log "Base packages installed successfully"

# Configure SSH
log "Configuring vulnerable SSH..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
log "SSH configured with root login and password authentication"

# Install DVWA
log "Installing DVWA..."
cd /var/www/html
if [ ! -d "DVWA" ]; then
    git clone https://github.com/digininja/DVWA.git
fi
chown -R www-data:www-data DVWA/
chmod -R 755 DVWA/

# Configure DVWA database
log "Configuring DVWA database..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure DVWA
cd /var/www/html/DVWA/config
cp config.inc.php.dist config.inc.php
sed -i "s/\$_DVWA\[ 'db_password' \]   = .*/\$_DVWA[ 'db_password' ]   = 'password';/" config.inc.php
systemctl restart apache2
log "DVWA installed and configured"

# Configure Docker API exposure
log "Configuring exposed Docker API..."
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375
EOF
systemctl daemon-reload
systemctl restart docker
log "Docker API exposed on port 2375"

# Create weak users
log "Creating weak user accounts..."
useradd -m -s /bin/bash admin 2>/dev/null || true
echo "admin:admin" | chpasswd
useradd -m -s /bin/bash backup 2>/dev/null || true
echo "backup:backup123" | chpasswd
useradd -m -s /bin/bash developer 2>/dev/null || true
echo "developer:dev123" | chpasswd

# Configure sudo for backup user
echo "backup ALL=(ALL) NOPASSWD: /usr/bin/rsync, /usr/bin/tar" > /etc/sudoers.d/backup
chmod 0440 /etc/sudoers.d/backup
log "Weak users created: admin, backup, developer"

# Create SUID binary
log "Creating SUID binary for privilege escalation..."
cp /bin/bash /usr/local/bin/rootbash
chmod u+s /usr/local/bin/rootbash
log "SUID binary created: /usr/local/bin/rootbash"

# Create vulnerable cron job
log "Creating vulnerable cron job..."
cat > /usr/local/bin/backup.sh <<EOF
#!/bin/bash
# Backup script - intentionally vulnerable
tar -czf /tmp/backup-\$(date +%Y%m%d).tar.gz /var/www/html
EOF
chmod 777 /usr/local/bin/backup.sh
echo "*/5 * * * * root /usr/local/bin/backup.sh" >> /etc/crontab
log "Vulnerable cron job created"

# Install AWS CLI
log "Installing AWS CLI..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
log "AWS CLI installed"

# Create exposed AWS credentials
log "Creating exposed AWS credentials..."
mkdir -p /home/developer/.aws
cat > /home/developer/.aws/credentials <<EOF
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
region = us-east-1
EOF
chmod 644 /home/developer/.aws/credentials
chown -R developer:developer /home/developer/.aws

# Create web config with credentials
mkdir -p /var/www/html/app
cat > /var/www/html/app/config.php <<EOF
<?php
// AWS Configuration - DO NOT COMMIT TO GIT
define('AWS_KEY', 'AKIAIOSFODNN7EXAMPLE');
define('AWS_SECRET', 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY');
define('AWS_REGION', 'us-east-1');
?>
EOF
chmod 644 /var/www/html/app/config.php
chown www-data:www-data /var/www/html/app/config.php
log "AWS credentials exposed in multiple locations"

# Configure NFS
log "Configuring open NFS shares..."
mkdir -p /srv/nfs/shared
mkdir -p /srv/nfs/backups
echo "Sensitive data here" > /srv/nfs/shared/confidential.txt
echo "Database backup" > /srv/nfs/backups/db_backup.sql

cat > /etc/exports <<EOF
/srv/nfs/shared *(rw,sync,no_root_squash,no_subtree_check)
/srv/nfs/backups *(rw,sync,no_root_squash,no_subtree_check)
/home *(rw,sync,no_root_squash,no_subtree_check)
EOF
exportfs -arv
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
log "NFS shares configured"

# Configure FTP
log "Configuring vulnerable FTP..."
cat > /etc/vsftpd.conf <<EOF
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
local_enable=YES
write_enable=YES
local_umask=022
anon_root=/srv/ftp
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
listen=YES
listen_ipv6=NO
EOF

mkdir -p /srv/ftp/upload
chmod 777 /srv/ftp/upload
echo "Welcome to vulnerable FTP server" > /srv/ftp/README.txt
systemctl enable vsftpd
systemctl restart vsftpd
log "FTP configured with anonymous access"

# Configure Samba
log "Configuring vulnerable Samba..."
mkdir -p /srv/samba/public
chmod 777 /srv/samba/public
echo "Public samba share - no authentication required" > /srv/samba/public/info.txt

cat >> /etc/samba/smb.conf <<EOF

[public]
   path = /srv/samba/public
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0777
   directory mask = 0777
   force user = nobody
EOF

systemctl enable smbd
systemctl restart smbd
log "Samba configured with guest access"

# Final summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║          Purple Team Lab Installation Complete!              ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "Services Status:"
echo "  • SSH:    $(systemctl is-active ssh)"
echo "  • Apache: $(systemctl is-active apache2)"
echo "  • Docker: $(systemctl is-active docker)"
echo "  • MySQL:  $(systemctl is-active mysql)"
echo "  • FTP:    $(systemctl is-active vsftpd)"
echo "  • NFS:    $(systemctl is-active nfs-kernel-server)"
echo "  • Samba:  $(systemctl is-active smbd)"
echo ""
warn "IMPORTANT: Next Steps"
echo "  1. Install Wazuh agent: ./07-install-wazuh-agent.sh"
echo "  2. Access DVWA: http://$(hostname -I | awk '{print $1}')/DVWA/"
echo "     Login: admin / password"
echo "  3. Review configuration files in /etc/"
echo "  4. Test vulnerabilities from Kali Linux"
echo ""
warn "SECURITY REMINDER"
echo "  • This system is INTENTIONALLY VULNERABLE"
echo "  • Keep on ISOLATED network only"
echo "  • Monitor with Wazuh SIEM"
echo "  • Document all activities"
echo ""
log "Installation complete. Happy purple teaming!"