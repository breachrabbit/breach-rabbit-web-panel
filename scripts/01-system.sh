#!/bin/bash
set -e

CONFIG_PROFILE=$1
MAX_WORKERS=$2

echo "Updating system packages..."
apt update && apt upgrade -y

echo "Installing base utilities..."
apt install -y curl wget git gnupg sudo ufw fail2ban htop unzip zip \
    software-properties-common apt-transport-https ca-certificates \
    build-essential libssl-dev libffi-dev python3 python3-pip

# SSH Hardening
echo "Hardening SSH configuration..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Firewall Configuration
echo "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 7080/tcp  # OLS Admin
ufw allow 3000/tcp  # Panel (temporary)
ufw --force enable

# Fail2ban Configuration
echo "Configuring Fail2ban..."
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600
findtime = 600

[nginx-http-auth]
enabled = true
port = http,https
logpath = %(nginx_error_log)s
maxretry = 3

[nginx-botsearch]
enabled = true
port = http,https
logpath = %(nginx_error_log)s
maxretry = 3
EOF

systemctl enable --now fail2ban

# Swap Configuration (if needed)
if [ "$TOTAL_RAM" -lt 4000 ]; then
    echo "Creating swap file for systems with <4GB RAM..."
    if [ ! -f /swapfile ]; then
        fallocate -l 1G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    fi
fi

# Sysctl Optimization
echo "Optimizing sysctl parameters..."
cat > /etc/sysctl.d/99-breach-rabbit.conf <<EOF
# Network optimizations
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.core.netdev_max_backlog = 1000

# Memory optimizations
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.overcommit_memory = 1

# File descriptors
fs.file-max = 100000
fs.inotify.max_user_watches = 524288

# Security
kernel.sysrq = 0
kernel.core_uses_pid = 1
EOF

sysctl -p /etc/sysctl.d/99-breach-rabbit.conf

# Timezone and Locale
echo "Setting timezone to UTC..."
timedatectl set-timezone UTC

# Create system info file
cat > /etc/motd <<'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      Breach Rabbit Web Panel                               ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF

echo "✓ System preparation complete"