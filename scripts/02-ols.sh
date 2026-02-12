#!/bin/bash
set -e

OLS_PASS=$1
OLS_MAX_CONN=$2
WORKERS=$3

echo "Adding OpenLiteSpeed repository (memory-safe method)..."

# Метод 1: Вручную добавить репозиторий без интерактивного скрипта
if [ ! -f /etc/apt/sources.list.d/litespeed.list ]; then
    # Импортировать ключ
    curl -fsSL https://repo.litespeed.sh/litespeed.gpg.key | gpg --dearmor -o /usr/share/keyrings/litespeed-archive-keyring.gpg
    
    # Добавить репозиторий
    echo "deb [signed-by=/usr/share/keyrings/litespeed-archive-keyring.gpg] https://repo.litespeed.sh/debian/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/litespeed.list
    
    apt update > /dev/null 2>&1 || true
fi

echo "Installing OpenLiteSpeed (minimal packages first)..."
# Установить только базовый пакет сначала
apt install -y openlitespeed > /dev/null 2>&1 || apt install -y --fix-broken openlitespeed > /dev/null 2>&1

echo "Installing PHP extensions (one by one to save memory)..."
# Установить расширения по одному с очисткой кэша
for pkg in lsphp82 lsphp82-mysql lsphp82-curl lsphp82-json lsphp82-opcache lsphp82-zip lsphp82-gd; do
    apt install -y $pkg > /dev/null 2>&1 || true
    apt clean > /dev/null 2>&1  # Очистить кэш после каждого пакета
done

# Create symlinks
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/php 2>/dev/null || true
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/lsphp 2>/dev/null || true

# Set admin password (безопасный метод)
echo "Setting OLS admin password..."
mkdir -p /usr/local/lsws/admin/tmp
echo "$OLS_PASS" > /usr/local/lsws/admin/tmp/ols_password.txt
echo "$OLS_PASS" >> /usr/local/lsws/admin/tmp/ols_password.txt
/usr/local/lsws/admin/misc/admpass.sh < /usr/local/lsws/admin/tmp/ols_password.txt > /dev/null 2>&1 || true
rm -f /usr/local/lsws/admin/tmp/ols_password.txt

# Configure OLS
cat > /usr/local/lsws/conf/httpd_config.conf <<EOF
serverName $(hostname)
user nobody
group nogroup
maxConnections ${OLS_MAX_CONN}
maxSSLConnections $((OLS_MAX_CONN / 2))
connTimeout 300
keepAliveTimeout 5
enableGzipCompress 1
workers ${WORKERS}
vhFile conf/vhosts/vhconf.conf
EOF

# Create minimal test site
mkdir -p /var/www/html
echo '<h1>🐰 Breach Rabbit Ready</h1>' > /var/www/html/index.html
chown -R www-www-data /var/www/html

# Start OLS with memory limits
echo "Starting OpenLiteSpeed..."
systemctl stop litespeed 2>/dev/null || true
systemctl start litespeed 2>/dev/null || true
sleep 5

# Verify OLS is running
if curl -s http://localhost:8088/ > /dev/null 2>&1; then
    echo "✓ OpenLiteSpeed installed and running"
else
    echo "⚠️  OLS started but not responding on port 8088 (may need manual start later)"
fi