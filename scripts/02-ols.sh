#!/bin/bash
set -e

OLS_ADMIN_PASSWORD=$1
OLS_MAX_CONN=$2
MAX_WORKERS=$3

echo "Adding OpenLiteSpeed repository..."
if [ ! -f /usr/local/lsws/bin/lswsctrl ]; then
    wget -O - https://repo.litespeed.sh | bash
fi

echo "Installing OpenLiteSpeed..."
apt install -y openlitespeed

# Install LSAPI for PHP
apt install -y lsphp82 lsphp82-mysql lsphp82-curl lsphp82-json \
    lsphp82-opcache lsphp82-zip lsphp82-gd lsphp82-imagick

# Create symlinks for convenience
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/lsphp
ln -sf /usr/local/lsws/lsphp82/bin/php /usr/bin/php
ln -sf /usr/local/lsws/lsphp82/bin/php-config /usr/bin/php-config
ln -sf /usr/local/lsws/lsphp82/bin/phpize /usr/bin/phpize

# Set OLS admin password
echo "Setting OLS admin password..."
(echo "$OLS_ADMIN_PASSWORD"; echo "$OLS_ADMIN_PASSWORD") | /usr/local/lsws/admin/misc/admpass.sh

# Configure OLS based on detected hardware
echo "Configuring OpenLiteSpeed..."
cat > /usr/local/lsws/conf/httpd_config.conf <<EOF
serverName                  $(hostname)
user                        nobody
group                       nogroup
priority                    0
autoRestart                 1
chrootPath                  /usr/local/lsws
enableChroot                0
inMemBufSize                4096
swappingDir                 /tmp/lshttpd/swap
autoFix503                  1
gracefulRestartTimeout      300

maxConnections              ${OLS_MAX_CONN}
maxSSLConnections           $((${OLS_MAX_CONN} / 2))
connTimeout                 300
maxKeepAliveReq             1000
smartKeepAlive              1
keepAliveTimeout            5
sndBufSize                  0
rcvBufSize                  0
maxReqURLLen                8192
maxReqHeaderSize            16380
maxReqBodySize              2047
maxDynRespHeaderSize        8192
maxDynRespSize              209715200
enableGzipCompress          1
enableDynGzipCompress       1
gzipCompressLevel           6
gzipAutoUpdateStatic        1
gzipMinFileSize             300

workers                     ${MAX_WORKERS}

eventLoopLimit              5000

disableInitLogRotation      0
enableLVE                   0
cloudLinux                  0

module default {
  lsapiApp
}

vhFile                      conf/vhosts/vhconf.conf
EOF

# Create default virtual host directory
mkdir -p /usr/local/lsws/conf/vhosts/default
cat > /usr/local/lsws/conf/vhosts/default/vhconf.conf <<'EOF'
docRoot                   $VH_ROOT/html/
vhDomain                  *

index  {
  useServer               0
  indexFiles              index.php, index.html
}

errorlog $SERVER_ROOT/logs/error.log {
  logLevel              NOTICE
  debugLevel            0
}

accesslog $SERVER_ROOT/logs/access.log

scripthandler  {
  add                     lsapi:lsphp82 php
}

phpIniOverride  {
  lsphp82 {
    memory_limit          128M
    max_execution_time    30
    max_input_time        60
    post_max_size         8M
    upload_max_filesize   2M
  }
}
EOF

# Create test site
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Breach Rabbit Web Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 600px;
            width: 100%;
        }
        h1 {
            color: #2c3e50;
            font-size: 2.5em;
            margin-bottom: 20px;
        }
        .rabbit {
            font-size: 4em;
            margin: 20px 0;
        }
        .success {
            color: #27ae60;
            font-size: 1.2em;
            margin: 20px 0;
            font-weight: 600;
        }
        p {
            color: #7f8c8d;
            margin: 10px 0;
            line-height: 1.6;
        }
        .info {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin: 20px 0;
            text-align: left;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="rabbit">🐰</div>
        <h1>Breach Rabbit Web Panel</h1>
        <div class="success">✅ Server Ready!</div>
        <p>Your server is configured and ready for the panel deployment.</p>
        
        <div class="info">
            <strong>Next Steps:</strong><br>
            1. Check credentials: /root/breach-rabbit-credentials.txt<br>
            2. Deploy the panel<br>
            3. Access admin panel at port 3000
        </div>
        
        <p style="margin-top: 30px; font-size: 0.9em; color: #95a5a6;">
            Powered by OpenLiteSpeed • Optimized for Performance
        </p>
    </div>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html

# Start and enable OLS
systemctl start litespeed
systemctl enable litespeed

# Wait for OLS to start
sleep 5

echo "✓ OpenLiteSpeed installed and configured"
echo "  Admin Panel: https://your-server:7080"
echo "  Username: admin"
echo "  Password: (saved in credentials file)"