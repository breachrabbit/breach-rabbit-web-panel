#!/bin/bash
# ============================================================================
# Breach Rabbit Web Panel - Complete Installer v1.0
# Optimized for 1 Core / 2GB RAM
# ============================================================================
set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

LOG_FILE="/var/log/breach-rabbit-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Breach Rabbit Web Panel - Complete Installer v1.0        ║${NC}"
echo -e "${CYAN}║  Optimized for 1 Core / 2GB RAM                           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Root check
[ "$EUID" -ne 0 ] && { echo -e "${RED}❌ Error: Run as root (sudo)${NC}"; exit 1; }

# Detect hardware
echo -e "${BLUE}[*] Detecting hardware configuration...${NC}"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
CPU_COUNT=$(nproc)
DISK_AVAILABLE=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')

if [ "$TOTAL_RAM" -lt 2000 ]; then
    PROFILE="minimal"
    WORKERS=1
    OLS_MAX_CONN=150
    PHP_MEMORY=96
    MYSQL_BUFFER=128
elif [ "$TOTAL_RAM" -lt 4000 ]; then
    PROFILE="standard"
    WORKERS=2
    OLS_MAX_CONN=300
    PHP_MEMORY=128
    MYSQL_BUFFER=256
else
    PROFILE="performance"
    WORKERS=$((CPU_COUNT > 4 ? 4 : CPU_COUNT))
    OLS_MAX_CONN=500
    PHP_MEMORY=192
    MYSQL_BUFFER=512
fi

echo -e "${GREEN}✓ Detected: ${CPU_COUNT} CPU cores, ${TOTAL_RAM}MB RAM${NC}"
echo -e "${YELLOW}⚠️  Profile: ${PROFILE} (workers: ${WORKERS})${NC}"
echo ""

# Generate credentials
echo -e "${BLUE}[*] Generating secure credentials...${NC}"
OLS_PASS=$(openssl rand -base64 20)
DB_PASS=$(openssl rand -base64 24)
DB_ROOT_PASS=$(openssl rand -base64 32)
REDIS_PASS=$(openssl rand -base64 16)
PANEL_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)

CRED_FILE="/root/breach-rabbit-credentials.txt"
cat > "$CRED_FILE" <<EOF
╔════════════════════════════════════════════════════════════╗
║  Breach Rabbit Web Panel - Credentials                    ║
╚════════════════════════════════════════════════════════════╝

Generated: $(date)
Profile: ${PROFILE}
Server: $(hostname)

══════════════════════════════════════════════════════════════

🔐 OLS Admin Panel
   URL: https://your-server:7080
   Username: admin
   Password: ${OLS_PASS}

══════════════════════════════════════════════════════════════

🗄️  Database (MariaDB)
   Host: localhost
   Port: 3306
   Database: panel_db
   User: panel_user
   Password: ${DB_PASS}
   Root Password: ${DB_ROOT_PASS}

══════════════════════════════════════════════════════════════

🔑 Panel API
   API Key: ${PANEL_KEY}
   JWT Secret: ${JWT_SECRET}

══════════════════════════════════════════════════════════════

💾 Redis
   Host: localhost
   Port: 6379
   Password: ${REDIS_PASS}

══════════════════════════════════════════════════════════════

⚠️  IMPORTANT: Save this file securely!
   Location: ${CRED_FILE}
══════════════════════════════════════════════════════════════
EOF

chmod 600 "$CRED_FILE"
echo -e "${GREEN}✓ Credentials saved to: ${CRED_FILE}${NC}"
echo ""

# Create directory structure
echo -e "${BLUE}[*] Creating directory structure...${NC}"
mkdir -p /opt/panel/{backend,backups,logs,temp} /var/www/{sites,html} /etc/panel/{ssl,config} /var/log/panel

# Create panel user
if ! id -u panel &>/dev/null; then
    adduser --disabled-password --gecos "" panel
    usermod -aG www-data panel 2>/dev/null || true
fi

# Set permissions
chown -R panel:www-data /opt/panel /var/www /etc/panel /var/log/panel
chmod -R 750 /opt/panel /etc/panel
chmod -R 755 /var/www

echo -e "${GREEN}✓ Directory structure created${NC}"
echo ""

# Run installation scripts
SCRIPTS_DIR="$(dirname "$0")/scripts"

# 01 - System
echo -e "${BLUE}[STEP 1/12] System preparation...${NC}"
bash "${SCRIPTS_DIR}/01-system.sh" "$TOTAL_RAM"

# 02 - OLS
echo -e "${BLUE}[STEP 2/12] Installing OpenLiteSpeed...${NC}"
bash "${SCRIPTS_DIR}/02-ols.sh" "$OLS_PASS" "$OLS_MAX_CONN" "$WORKERS"

# 03 - PHP versions
echo -e "${BLUE}[STEP 3/12] Installing PHP 8.3/8.4/8.5 with WordPress extensions...${NC}"
bash "${SCRIPTS_DIR}/03-php-versions.sh" "$PHP_MEMORY"

# 04 - Redis
echo -e "${BLUE}[STEP 4/12] Installing Redis...${NC}"
bash "${SCRIPTS_DIR}/04-redis.sh" "$REDIS_PASS" "$TOTAL_RAM"

# 05 - Nginx
echo -e "${BLUE}[STEP 5/12] Installing Nginx...${NC}"
bash "${SCRIPTS_DIR}/05-nginx.sh" "$WORKERS"

# 06 - Database
echo -e "${BLUE}[STEP 6/12] Installing MariaDB...${NC}"
bash "${SCRIPTS_DIR}/06-database.sh" "$DB_PASS" "$DB_ROOT_PASS" "$MYSQL_BUFFER"

# 07 - Node.js
echo -e "${BLUE}[STEP 7/12] Installing Node.js and PM2...${NC}"
bash "${SCRIPTS_DIR}/07-nodejs.sh"

# 08 - acme.sh
echo -e "${BLUE}[STEP 8/12] Installing acme.sh for SSL...${NC}"
bash "${SCRIPTS_DIR}/08-acme.sh"

# 09 - Next.js Deploy
echo -e "${BLUE}[STEP 9/12] Deploying Next.js Panel...${NC}"
bash "${SCRIPTS_DIR}/09-nextjs-deploy.sh"

# 10 - Panel Config
echo -e "${BLUE}[STEP 10/12] Configuring Panel environment...${NC}"
bash "${SCRIPTS_DIR}/10-panel-config.sh" "$DB_PASS" "$REDIS_PASS" "$JWT_SECRET" "$PANEL_KEY"

# 11 - Optimization
echo -e "${BLUE}[STEP 11/12] Optimizing for detected hardware...${NC}"
bash "${SCRIPTS_DIR}/11-optimization.sh" "$PROFILE" "$TOTAL_RAM" "$CPU_COUNT" "$WORKERS" "$PHP_MEMORY" "$MYSQL_BUFFER"

# 12 - Finalize
echo -e "${BLUE}[STEP 12/12] Finalizing installation...${NC}"
bash "${SCRIPTS_DIR}/12-finalize.sh" "$CRED_FILE"

# Final message
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Installation Complete!                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Configuration Summary:${NC}"
echo -e "   Profile: ${PROFILE}"
echo -e "   CPU Cores: ${CPU_COUNT}"
echo -e "   RAM: ${TOTAL_RAM}MB"
echo -e "   Workers: ${WORKERS}"
echo ""
echo -e "${YELLOW}🔑 Important:${NC}"
echo -e "   Credentials: ${CRED_FILE}"
echo -e "   OLS Admin: https://your-server:7080"
echo -e "   Panel UI: http://your-server:3000"
echo ""
echo -e "${BLUE}🚀 Start the panel:${NC}"
echo -e "   sudo -u panel pm2 start /opt/panel/backend/ecosystem.config.js"
echo -e "   sudo -u panel pm2 save"
echo ""
echo -e "${GREEN}📄 Log: ${LOG_FILE}${NC}"