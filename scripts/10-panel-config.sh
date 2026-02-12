#!/bin/bash
set -e

DB_PASS=$1
REDIS_PASS=$2
JWT_SECRET=$3
PANEL_KEY=$4

echo "Configuring panel environment (SAFE MODE)..."

cd /opt/panel/backend

# Создать ecosystem.config.js с лимитами памяти
cat > ecosystem.config.js <<'EOF'
module.exports = {
  apps: [{
    name: 'breach-rabbit-panel',
    cwd: '/opt/panel/backend',
    script: 'node_modules/next/dist/bin/next',
    args: 'start',
    instances: 1,
    autorestart: true,
    max_memory_restart: '400M',  // КРИТИЧЕСКИ ВАЖНО для 2GB RAM
    env: {
      NODE_ENV: 'production',
      PORT: '3000',
      NODE_OPTIONS: '--max-old-space-size=300'  // Лимит памяти для Node.js
    },
    error_file: '/var/log/panel/error.log',
    out_file: '/var/log/panel/out.log',
    watch: false,
    min_uptime: '15000',
    max_restarts: 3,
    restart_delay: 5000
  }]
};
EOF

chown panel:panel ecosystem.config.js

# Создать .env
cat > .env <<EOF
DATABASE_URL="mysql://panel_user:${DB_PASS}@localhost:3306/panel_db"
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=panel_db
DATABASE_USER=panel_user
DATABASE_PASSWORD=${DB_PASS}
NEXT_PUBLIC_API_URL=http://localhost:3000
NODE_ENV=production
PORT=3000
JWT_SECRET=${JWT_SECRET}
PANEL_SECRET_KEY=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)
OLS_API_URL=https://localhost:7080/rest/v1
OLS_API_KEY=${PANEL_KEY}
OLS_ADMIN_USER=admin
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASS}
SITES_PATH=/var/www/sites
BACKUP_PATH=/opt/panel/backups
LOG_PATH=/var/log/panel
ACME_HOME=/home/panel/.acme.sh
SSL_PATH=/etc/panel/ssl
EOF

chown panel:panel .env
chmod 600 .env

# Создать схему БД
mysql -u panel_user -p"${DB_PASS}" panel_db <<'EOF'
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin','user') DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT true
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS websites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) UNIQUE NOT NULL,
  root_path VARCHAR(512) NOT NULL,
  php_version VARCHAR(10) DEFAULT '8.3',
  type ENUM('static','php','proxy') DEFAULT 'php',
  ssl_enabled BOOLEAN DEFAULT false,
  ssl_expires_at DATETIME,
  status ENUM('active','suspended','deleted') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_domain (domain),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ssl_certificates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) NOT NULL,
  cert_path VARCHAR(512),
  key_path VARCHAR(512),
  expires_at DATETIME NOT NULL,
  auto_renew BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_domain (domain),
  INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS databases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  user VARCHAR(100) NOT NULL,
  password VARCHAR(255) NOT NULL,
  host VARCHAR(100) DEFAULT 'localhost',
  type ENUM('mysql','mariadb','postgresql') DEFAULT 'mariadb',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users (username, email, password_hash, role, is_active) 
VALUES ('admin', 'admin@localhost', '$2b$10$rQZ5YHj8KzX9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z', 'admin', true)
ON DUPLICATE KEY UPDATE role='admin', is_active=true;
EOF

# Создать скрипт ЗАПУСКА с защитой от OOM
cat > /usr/local/bin/panel-safe-start <<'SAFE_EOF'
#!/bin/bash
set -e

echo "🔍 Checking available memory before panel start..."
FREE_MEM=$(free -m | awk '/^Mem:/{print $7}')
SWAP_FREE=$(free -m | awk '/^Swap:/{print $4}')

echo "   Free RAM: ${FREE_MEM}MB"
echo "   Free Swap: ${SWAP_FREE}MB"

if [ "$FREE_MEM" -lt 300 ]; then
  echo "❌ CRITICAL: Less than 300MB free RAM. Stopping to prevent SSH lockout!"
  echo "   Please stop some services first:"
  echo "     sudo systemctl stop litespeed    # Stop OLS temporarily"
  echo "     sudo systemctl stop mariadb      # Stop DB temporarily"
  echo "   Then run: panel-safe-start"
  exit 1
fi

if [ "$SWAP_FREE" -lt 500 ]; then
  echo "⚠️  Low swap space (${SWAP_FREE}MB). Increasing swap to 2GB..."
  if [ ! -f /swapfile2 ]; then
    fallocate -l 2G /swapfile2
    chmod 600 /swapfile2
    mkswap /swapfile2
    swapon /swapfile2
    echo '/swapfile2 none swap sw 0 0' >> /etc/fstab
  fi
fi

echo "✅ Memory check passed. Starting panel..."
sudo -u panel pm2 start /opt/panel/backend/ecosystem.config.js
sudo -u panel pm2 save

echo ""
echo "🚀 Panel started successfully!"
echo "   Access: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "💡 If SSH disconnects:"
echo "   1. Wait 2-3 minutes for system to stabilize"
echo "   2. Reconnect via SSH"
echo "   3. Check memory: free -h"
echo "   4. Stop panel if needed: sudo -u panel pm2 stop all"
SAFE_EOF

chmod +x /usr/local/bin/panel-safe-start

echo "✓ Panel environment configured SAFELY"
echo "⚠️  DO NOT start panel automatically!"
echo "✅ Use 'panel-safe-start' command to start with memory protection"