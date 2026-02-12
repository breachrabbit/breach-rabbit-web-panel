#!/bin/bash
set -e

OLS_PASS=$1
OLS_MAX_CONN=$2
WORKERS=$3

echo "Adding OpenLiteSpeed repository..."
wget -qO - https://repo.litespeed.sh | bash > /dev/null 2>&1 || true

echo "Installing OpenLiteSpeed..."
apt install -y openlitespeed lsphp82 lsphp82-mysql lsphp82-curl \
    lsphp82-json lsphp82-opcache lsphp82-zip lsphp82-gd > /dev/null 2>&1

# Create symlinks
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/php 2>/dev/null || true
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/lsphp 2>/dev/null || true

# Set admin password
echo "Setting OLS admin password..."
(echo "$OLS_PASS"; echo "$OLS_PASS") | /usr/local/lsws/admin/misc/admpass.sh > /dev/null 2>&1

# Configure OLS
cat > /usr/local/lsws/conf/httpd_config.conf <<EOF
serverName                  $(hostname)
user                        nobody
group                       nogroup
maxConnections              ${OLS_MAX_CONN}
maxSSLConnections           $((OLS_MAX_CONN / 2))
connTimeout                 300
keepAliveTimeout            5
enableGzipCompress          1
workers                     ${WORKERS}
vhFile                      conf/vhosts/vhconf.conf
EOF

# Create test site
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Breach Rabbit</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 100px; background: linear-gradient(135deg, #667eea, #764ba2); color: white; }
        .rabbit { font-size: 5em; margin: 30px 0; }
        h1 { font-size: 2.5em; }
    </style>
</head>
<body>
    <div class="rabbit">🐰</div>
    <h1>Breach Rabbit Web Panel</h1>
    <p>Server ready for panel deployment</p>
</body>
</html>
HTML_EOF

chown -R www-data:www-data /var/www/html

# Start OLS
systemctl start litespeed 2>/dev/null || true
systemctl enable litespeed 2>/dev/null || true
sleep 3

echo "✓ OpenLiteSpeed installed"