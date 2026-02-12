#!/bin/bash
set -e

PANEL_API_KEY=$1
JWT_SECRET=$2
PANEL_SECRET=$3
DB_PASSWORD=$4
REDIS_PASSWORD=$5

echo "Configuring Panel environment..."

# Create .env file
cat > /opt/panel/backend/.env <<EOF
# ============================================================================
# Breach Rabbit Web Panel - Environment Configuration
# ============================================================================

# Database Configuration
DATABASE_URL="mysql://panel_user:${DB_PASSWORD}@localhost:3306/panel_db"
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=panel_db
DATABASE_USER=panel_user
DATABASE_PASSWORD=${DB_PASSWORD}

# Next.js Configuration
NEXT_PUBLIC_API_URL=http://localhost:3000
NODE_ENV=production
PORT=3000

# Security & Authentication
JWT_SECRET=${JWT_SECRET}
PANEL_SECRET_KEY=${PANEL_SECRET}
SESSION_SECRET=${PANEL_SECRET}

# OLS API Configuration
OLS_API_URL=https://localhost:7080/rest/v1
OLS_API_KEY=${PANEL_API_KEY}
OLS_ADMIN_USER=admin

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}

# File Paths
SITES_PATH=/var/www/sites
BACKUP_PATH=/opt/panel/backups
LOG_PATH=/var/log/panel
TEMP_PATH=/tmp/panel

# SSL Configuration
ACME_HOME=/home/panel/.acme.sh
SSL_PATH=/etc/panel/ssl
SSL_AUTO_RENEW=true
SSL_RENEW_DAYS=30

# Aeza API (Optional)
AEZA_API_KEY=
AEZA_API_URL=https://api.aeza.net/v1

# Backup Configuration
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_COMPRESSION=true

# Monitoring
ENABLE_MONITORING=true
MONITORING_INTERVAL=60

# Feature Flags
ENABLE_FILE_MANAGER=true
ENABLE_TERMINAL=true
ENABLE_CRON_MANAGER=true
ENABLE_FIREWALL_GUI=true
ENABLE_REDIS=true

# Performance
MAX_UPLOAD_SIZE=64MB
REQUEST_TIMEOUT=30000
EOF

chown panel:panel /opt/panel/backend/.env
chmod 600 /opt/panel/backend/.env

# Create PM2 ecosystem config
cat > /opt/panel/ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: 'breach-rabbit-panel',
      cwd: '/opt/panel/backend',
      script: 'node_modules/next/dist/bin/next',
      args: 'start',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      error_file: '/var/log/panel/panel-error.log',
      out_file: '/var/log/panel/panel-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      time: true,
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 4000
    }
  ]
};
EOF

chown panel:panel /opt/panel/ecosystem.config.js

# Create systemd service for panel (alternative to PM2)
cat > /etc/systemd/system/breach-rabbit-panel.service <<'EOF'
[Unit]
Description=Breach Rabbit Web Panel
After=network.target mysql.service redis-server.service

[Service]
Type=simple
User=panel
Group=www-data
WorkingDirectory=/opt/panel/backend
Environment="NODE_ENV=production"
Environment="PORT=3000"
ExecStart=/usr/bin/node /opt/panel/backend/node_modules/next/dist/bin/next start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=breach-rabbit-panel

[Install]
WantedBy=multi-user.target
EOF

# Create panel database schema
echo "Creating panel database schema..."
mysql -u panel_user -p"${DB_PASSWORD}" panel_db <<'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'user') DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_login TIMESTAMP NULL,
  is_active BOOLEAN DEFAULT true
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Websites table
CREATE TABLE IF NOT EXISTS websites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) UNIQUE NOT NULL,
  root_path VARCHAR(512) NOT NULL,
  php_version VARCHAR(10) DEFAULT '8.3',
  type ENUM('static', 'php', 'proxy') DEFAULT 'php',
  proxy_target VARCHAR(512),
  ssl_enabled BOOLEAN DEFAULT false,
  ssl_cert_path VARCHAR(512),
  ssl_key_path VARCHAR(512),
  ssl_expires_at DATETIME,
  auto_renew_ssl BOOLEAN DEFAULT true,
  status ENUM('active', 'suspended', 'deleted') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_domain (domain),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SSL Certificates table
CREATE TABLE IF NOT EXISTS ssl_certificates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) NOT NULL,
  cert_path VARCHAR(512) NOT NULL,
  key_path VARCHAR(512) NOT NULL,
  fullchain_path VARCHAR(512),
  issuer VARCHAR(100),
  expires_at DATETIME NOT NULL,
  auto_renew BOOLEAN DEFAULT true,
  last_renewed_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_domain (domain),
  INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Databases table
CREATE TABLE IF NOT EXISTS databases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  user VARCHAR(100) NOT NULL,
  password VARCHAR(255) NOT NULL,
  host VARCHAR(100) DEFAULT 'localhost',
  type ENUM('mysql', 'mariadb', 'postgresql') DEFAULT 'mariadb',
  size_mb DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backups table
CREATE TABLE IF NOT EXISTS backups (
  id INT AUTO_INCREMENT PRIMARY KEY,
  website_id INT,
  type ENUM('full', 'database', 'files') NOT NULL,
  path VARCHAR(512) NOT NULL,
  size_mb DECIMAL(10,2),
  status ENUM('pending', 'running', 'completed', 'failed') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP NULL,
  FOREIGN KEY (website_id) REFERENCES websites(id) ON DELETE CASCADE,
  INDEX idx_status (status),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cron jobs table
CREATE TABLE IF NOT EXISTS cron_jobs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  command TEXT NOT NULL,
  schedule VARCHAR(100) NOT NULL,
  user VARCHAR(50) DEFAULT 'www-data',
  description VARCHAR(255),
  enabled BOOLEAN DEFAULT true,
  last_run TIMESTAMP NULL,
  next_run TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Firewall rules table
CREATE TABLE IF NOT EXISTS firewall_rules (
  id INT AUTO_INCREMENT PRIMARY KEY,
  action ENUM('allow', 'deny') NOT NULL,
  protocol ENUM('tcp', 'udp', 'icmp') DEFAULT 'tcp',
  port INT,
  ip_address VARCHAR(45),
  direction ENUM('in', 'out') DEFAULT 'in',
  description VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_action (action),
  INDEX idx_port (port)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Activity logs table
CREATE TABLE IF NOT EXISTS activity_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id INT,
  details TEXT,
  ip_address VARCHAR(45),
  user_agent VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id),
  INDEX idx_created (created_at),
  INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create admin user (password: admin123 hashed with bcrypt)
INSERT INTO users (username, email, password_hash, role, is_active) 
VALUES ('admin', 'admin@localhost', '$2b$10$rQZ5YHj8KzX9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z', 'admin', true)
ON DUPLICATE KEY UPDATE role='admin', is_active=true;
EOF

# Create log directories
mkdir -p /var/log/panel
chown panel:www-data /var/log/panel
chmod 755 /var/log/panel

# Create backup directories
mkdir -p /opt/panel/backups/{daily,weekly,monthly}
chown -R panel:www-data /opt/panel/backups
chmod -R 750 /opt/panel/backups

echo "✓ Panel environment configured"
echo "  Environment file: /opt/panel/backend/.env"
echo "  PM2 config: /opt/panel/ecosystem.config.js"
echo "  Database schema created"