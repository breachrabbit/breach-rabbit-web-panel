#!/bin/bash

# ============================================================================
# Breach Rabbit Web Panel - Auto Installer
# Автоматическое определение конфигурации и оптимизация
# ============================================================================
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/var/log/breach-rabbit-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Версия панели
PANEL_VERSION="1.0.0"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║      Breach Rabbit Web Panel Installer v${PANEL_VERSION}              ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Проверка прав
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Error: Please run as root (sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Starting installation...${NC}"
echo -e "${BLUE}[*] Log file: ${LOG_FILE}${NC}"
echo ""

# ============================================================================
# ШАГ 0: Определение конфигурации сервера
# ============================================================================
echo -e "${YELLOW}[STEP 0] Detecting server configuration...${NC}"

# Определение ОС
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}❌ Error: Unsupported operating system${NC}"
    exit 1
fi

source /etc/os-release
OS_NAME="$NAME"
OS_VERSION="$VERSION_ID"

echo -e "${GREEN}✓ OS: ${OS_NAME} ${OS_VERSION}${NC}"

# Определение ресурсов
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
CPU_COUNT=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name: *//')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')

echo -e "${GREEN}✓ CPU: ${CPU_COUNT} cores (${CPU_MODEL})${NC}"
echo -e "${GREEN}✓ RAM: ${TOTAL_RAM}MB${NC}"
echo -e "${GREEN}✓ Swap: ${TOTAL_SWAP}MB${NC}"
echo -e "${GREEN}✓ Disk: ${DISK_AVAILABLE} available of ${DISK_TOTAL}${NC}"

# Автоматическое определение конфигурации
if [ "$TOTAL_RAM" -lt 2000 ]; then
    CONFIG_PROFILE="minimal"
    MAX_WORKERS=1
    OLS_MAX_CONN=150
    PHP_MEMORY=96
    MYSQL_BUFFER=128
elif [ "$TOTAL_RAM" -lt 4000 ]; then
    CONFIG_PROFILE="standard"
    MAX_WORKERS=2
    OLS_MAX_CONN=300
    PHP_MEMORY=128
    MYSQL_BUFFER=256
elif [ "$TOTAL_RAM" -lt 8000 ]; then
    CONFIG_PROFILE="performance"
    MAX_WORKERS=4
    OLS_MAX_CONN=500
    PHP_MEMORY=192
    MYSQL_BUFFER=512
else
    CONFIG_PROFILE="high_performance"
    MAX_WORKERS=8
    OLS_MAX_CONN=1000
    PHP_MEMORY=256
    MYSQL_BUFFER=1024
fi

echo -e "${YELLOW}⚠️  Detected configuration profile: ${CONFIG_PROFILE}${NC}"
echo -e "${YELLOW}⚠️  Optimizing for: ${MAX_WORKERS} workers, ${TOTAL_RAM}MB RAM${NC}"
echo ""

# ============================================================================
# ШАГ 1: Генерация паролей и сохранение
# ============================================================================
echo -e "${YELLOW}[STEP 1] Generating secure credentials...${NC}"

# Генерация паролей
ADMIN_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 24)
DB_ROOT_PASSWORD=$(openssl rand -base64 32)
OLS_ADMIN_PASSWORD=$(openssl rand -base64 20)
PANEL_API_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
PANEL_SECRET=$(openssl rand -hex 32)
REDIS_PASSWORD=$(openssl rand -base64 16)

# Сохранение паролей
CREDENTIALS_FILE="/root/breach-rabbit-credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOF
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      Breach Rabbit Web Panel - Credentials                 ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Generated on: $(date)
Server: $(hostname)
Profile: ${CONFIG_PROFILE}

══════════════════════════════════════════════════════════════

🔐 OLS Admin Panel
   URL: https://your-server:7080
   Username: admin
   Password: ${OLS_ADMIN_PASSWORD}

══════════════════════════════════════════════════════════════

🗄️  Database (MariaDB)
   Host: localhost
   Port: 3306
   Database: panel_db
   User: panel_user
   Password: ${DB_PASSWORD}
   
   Root User: root
   Root Password: ${DB_ROOT_PASSWORD}

══════════════════════════════════════════════════════════════

🔑 Panel API
   API Key: ${PANEL_API_KEY}
   JWT Secret: ${JWT_SECRET}
   Panel Secret: ${PANEL_SECRET}

══════════════════════════════════════════════════════════════

💾 Redis
   Host: localhost
   Port: 6379
   Password: ${REDIS_PASSWORD}

══════════════════════════════════════════════════════════════

⚠️  IMPORTANT:
   1. Save this file in a secure location
   2. Change passwords after first login
   3. Do not share this file publicly
   4. Backup this file securely

══════════════════════════════════════════════════════════════
EOF

chmod 600 "$CREDENTIALS_FILE"

echo -e "${GREEN}✓ Credentials generated and saved to: ${CREDENTIALS_FILE}${NC}"
echo -e "${YELLOW}⚠️  IMPORTANT: Save this file securely!${NC}"
echo ""

# ============================================================================
# ШАГ 2: Создание структуры директорий
# ============================================================================
echo -e "${YELLOW}[STEP 2] Creating directory structure...${NC}"

# Основные директории
mkdir -p /opt/panel/{backend,frontend,logs,backups,temp}
mkdir -p /var/www/{sites,html}
mkdir -p /etc/panel/{ssl,config,logs}
mkdir -p /var/log/panel
mkdir -p /var/lib/panel/{databases,backups}

# Создание пользователя panel
if ! id -u panel &>/dev/null; then
    echo "Creating panel user..."
    adduser --disabled-password --gecos "" panel
    usermod -aG www-data panel
    usermod -aG redis panel 2>/dev/null || true
fi

# Назначение прав
chown -R panel:www-data /opt/panel
chown -R www-data:www-data /var/www
chmod -R 750 /opt/panel
chmod -R 755 /var/www
chown -R panel:www-data /etc/panel
chmod 750 /etc/panel
chown panel:www-data /var/log/panel
chmod 755 /var/log/panel

echo -e "${GREEN}✓ Directory structure created${NC}"
echo ""

# ============================================================================
# ШАГ 3: Запуск скриптов установки
# ============================================================================
SCRIPTS_DIR="$(dirname "$0")/scripts"

# 00 - Детектирование (уже выполнено)

# 01 - Базовая система
echo -e "${BLUE}[STEP 3/12] System preparation...${NC}"
bash "${SCRIPTS_DIR}/01-system.sh" "$CONFIG_PROFILE" "$MAX_WORKERS"

# 02 - OpenLiteSpeed
echo -e "${BLUE}[STEP 4/12] Installing OpenLiteSpeed...${NC}"
bash "${SCRIPTS_DIR}/02-ols.sh" "$OLS_ADMIN_PASSWORD" "$OLS_MAX_CONN" "$MAX_WORKERS"

# 03 - PHP версии
echo -e "${BLUE}[STEP 5/12] Installing PHP 8.3, 8.4, 8.5 with WordPress extensions...${NC}"
bash "${SCRIPTS_DIR}/03-php-versions.sh" "$PHP_MEMORY" "$CONFIG_PROFILE"

# 04 - Redis
echo -e "${BLUE}[STEP 6/12] Installing Redis...${NC}"
bash "${SCRIPTS_DIR}/04-redis.sh" "$REDIS_PASSWORD" "$TOTAL_RAM"

# 05 - Nginx
echo -e "${BLUE}[STEP 7/12] Installing Nginx...${NC}"
bash "${SCRIPTS_DIR}/05-nginx.sh" "$MAX_WORKERS"

# 06 - Database
echo -e "${BLUE}[STEP 8/12] Installing MariaDB...${NC}"
bash "${SCRIPTS_DIR}/06-database.sh" "$DB_PASSWORD" "$DB_ROOT_PASSWORD" "$MYSQL_BUFFER"

# 07 - Node.js
echo -e "${BLUE}[STEP 9/12] Installing Node.js and PM2...${NC}"
bash "${SCRIPTS_DIR}/07-nodejs.sh"

# 08 - acme.sh
echo -e "${BLUE}[STEP 10/12] Installing acme.sh for SSL...${NC}"
bash "${SCRIPTS_DIR}/08-acme.sh"

# 09 - Next.js Deploy
echo -e "${BLUE}[STEP 11/12] Deploying Next.js Panel from GitHub...${NC}"
bash "${SCRIPTS_DIR}/09-nextjs-deploy.sh"

# 10 - Panel Config
echo -e "${BLUE}[STEP 12/12] Configuring Panel...${NC}"
bash "${SCRIPTS_DIR}/10-panel-config.sh" "$PANEL_API_KEY" "$JWT_SECRET" "$PANEL_SECRET" "$DB_PASSWORD" "$REDIS_PASSWORD"

# 11 - Optimization
echo -e "${BLUE}[STEP 13/12] Optimizing for detected configuration...${NC}"
bash "${SCRIPTS_DIR}/11-optimization.sh" "$CONFIG_PROFILE" "$TOTAL_RAM" "$CPU_COUNT" "$MAX_WORKERS" "$PHP_MEMORY" "$MYSQL_BUFFER"

# 12 - Finalize
echo -e "${BLUE}[STEP 14/12] Finalizing installation...${NC}"
bash "${SCRIPTS_DIR}/12-finalize.sh" "$CREDENTIALS_FILE"

# ============================================================================
# ФИНАЛЬНОЕ СООБЩЕНИЕ
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║         ✅ Installation Complete!                          ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Configuration Summary:${NC}"
echo -e "   Profile: ${CONFIG_PROFILE}"
echo -e "   CPU Cores: ${CPU_COUNT}"
echo -e "   RAM: ${TOTAL_RAM}MB"
echo -e "   Workers: ${MAX_WORKERS}"
echo ""
echo -e "${YELLOW}🔑 Important Information:${NC}"
echo -e "   1. Credentials: ${CREDENTIALS_FILE}"
echo -e "   2. OLS Admin: https://your-server:7080"
echo -e "   3. Panel UI: http://your-server:3000"
echo -e "   4. Test Site: http://your-server/"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo -e "   1. View credentials: cat ${CREDENTIALS_FILE}"
echo -e "   2. Start the panel: sudo -u panel pm2 start /opt/panel/backend/ecosystem.config.js"
echo -e "   3. Check status: sudo -u panel pm2 status"
echo -e "   4. View logs: sudo -u panel pm2 logs"
echo ""
echo -e "${GREEN}📝 Installation log: ${LOG_FILE}${NC}"
echo ""
echo -e "${CYAN}💡 Quick Commands:${NC}"
echo -e "   panel-logs      - View panel logs"
echo -e "   panel-restart   - Restart panel"
echo -e "   panel-status    - Check panel status"
echo -e "   ols-restart     - Restart OpenLiteSpeed"
echo -e "   nginx-restart   - Restart Nginx"
echo ""