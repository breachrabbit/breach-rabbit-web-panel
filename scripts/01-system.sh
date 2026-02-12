#!/bin/bash
set -e

TOTAL_RAM=$1

echo "Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt upgrade -y > /dev/null 2>&1

echo "Installing base utilities..."
apt install -y curl wget git gnupg ufw fail2ban htop unzip zip \
    software-properties-common apt-transport-https ca-certificates \
    build-essential libssl-dev > /dev/null 2>&1

# SSH Hardening (БЕЗОПАСНАЯ ВЕРСИЯ для Ubuntu/Debian)
echo "Hardening SSH configuration..."
if [ -f /etc/ssh/sshd_config ]; then
    # Разрешаем только ключи, запрещаем root и пароли
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    
    # Применяем изменения БЕЗ разрыва текущей сессии
    if systemctl is-active --quiet ssh 2>/dev/null; then
        systemctl reload ssh 2>/dev/null || true
    elif systemctl is-active --quiet sshd 2>/dev/null; then
        systemctl reload sshd 2>/dev/null || true
    fi
    echo "✓ SSH hardened (reload applied safely)"
else
    echo "⚠️  SSH config not found, skipping hardening"
fi

# Firewall
echo "Configuring firewall..."
ufw --force reset > /dev/null 2>&1 || true
ufw default deny incoming > /dev/null 2>&1 || true
ufw default allow outgoing > /dev/null 2>&1 || true
ufw allow 22/tcp > /dev/null 2>&1    # SSH
ufw allow 80/tcp > /dev/null 2>&1    # HTTP
ufw allow 443/tcp > /dev/null 2>&1   # HTTPS
ufw allow 7080/tcp > /dev/null 2>&1  # OLS Admin
ufw allow 3000/tcp > /dev/null 2>&1  # Panel
ufw --force enable > /dev/null 2>&1 || true

# Swap for low RAM (увеличиваем до 2GB для 2GB RAM систем)
if [ "$TOTAL_RAM" -lt 4000 ] && [ ! -f /swapfile ]; then
    echo "Creating swap file (2GB for stability)..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Sysctl optimization
cat > /etc/sysctl.d/99-breach-rabbit.conf <<EOF
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.file-max = 100000
kernel.sysrq = 0
kernel.core_uses_pid = 1
EOF

sysctl -p /etc/sysctl.d/99-breach-rabbit.conf > /dev/null 2>&1 || true

echo "✓ System preparation complete"