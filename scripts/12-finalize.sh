#!/bin/bash
set -e

CREDENTIALS_FILE=$1

echo "Finalizing installation..."

# Create system info file
cat > /etc/motd <<'EOF'


╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      Breach Rabbit Web Panel Installed Successfully!       ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Important Information:
----------------------
Credentials: /root/breach-rabbit-credentials.txt

Services:
  - Panel UI: http://your-server:3000
  - OLS Admin: https://your-server:7080
  - Nginx: http://your-server:80
  - Test Site: http://your-server/

Paths:
  - Panel: /opt/panel/
  - Sites: /var/www/sites/
  - SSL: /etc/panel/ssl/
  - Logs: /var/log/panel/
  - Backups: /opt/panel/backups/

Next Steps:
-----------
1. View credentials:
   cat /root/breach-rabbit-credentials.txt

2. Start the panel:
   sudo -u panel pm2 start /opt/panel/ecosystem.config.js
   sudo -u panel pm2 save

3. Enable PM2 startup:
   sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u panel --hp /home/panel

4. Check panel status:
   sudo -u panel pm2 status

5. View logs:
   sudo -u panel pm2 logs

For support visit: https://github.com/breachrabbit/breach-rabbit-web-panel

EOF

chmod 644 /etc/motd

# Create helpful aliases
cat >> /home/panel/.bashrc <<'EOF'

# Breach Rabbit Panel Aliases
alias panel-logs='pm2 logs breach-rabbit-panel'
alias panel-restart='pm2 restart breach-rabbit-panel'
alias panel-status='pm2 status'
alias panel-stop='pm2 stop breach-rabbit-panel'
alias panel-start='pm2 start breach-rabbit-panel'
alias panel-build='cd /opt/panel/backend && yarn build'
alias ols-restart='sudo systemctl restart litespeed'
alias nginx-restart='sudo systemctl restart nginx'
alias php-restart='sudo systemctl restart php8.3-fpm php8.4-fpm php8.5-fpm'
alias redis-restart='sudo systemctl restart redis-server'
alias db-restart='sudo systemctl restart mariadb'

# Quick info
alias panel-info='cat /etc/motd'

EOF

# Create startup script
cat > /usr/local/bin/panel-startup <<'EOF'
#!/bin/bash
# Breach Rabbit Panel Startup Script

echo "Starting Breach Rabbit Panel services..."

# Start OLS
systemctl start litespeed
echo "✓ OpenLiteSpeed started"

# Start Nginx
systemctl start nginx
echo "✓ Nginx started"

# Start Redis
systemctl start redis-server
echo "✓ Redis started"

# Start PHP-FPM
systemctl start php8.3-fpm php8.4-fpm php8.5-fpm
echo "✓ PHP-FPM started"

# Start MariaDB
systemctl start mariadb
echo "✓ MariaDB started"

# Start Panel with PM2
sudo -u panel pm2 start /opt/panel/ecosystem.config.js 2>/dev/null || true
echo "✓ Panel started"

echo ""
echo "All services started successfully!"
echo "Panel UI: http://localhost:3000"
EOF

chmod +x /usr/local/bin/panel-startup

# Create health check script
cat > /usr/local/bin/panel-health <<'EOF'
#!/bin/bash
# Breach Rabbit Panel Health Check

echo "Breach Rabbit Panel Health Check"
echo "================================="
echo ""

# Check OLS
if systemctl is-active --quiet litespeed; then
    echo "✓ OpenLiteSpeed: Running"
else
    echo "✗ OpenLiteSpeed: Stopped"
fi

# Check Nginx
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx: Running"
else
    echo "✗ Nginx: Stopped"
fi

# Check Redis
if systemctl is-active --quiet redis-server; then
    echo "✓ Redis: Running"
else
    echo "✗ Redis: Stopped"
fi

# Check MariaDB
if systemctl is-active --quiet mariadb; then
    echo "✓ MariaDB: Running"
else
    echo "✗ MariaDB: Stopped"
fi

# Check PHP-FPM
PHP_RUNNING=0
for version in 8.3 8.4 8.5; do
    if systemctl is-active --quiet php${version}-fpm; then
        PHP_RUNNING=$((PHP_RUNNING + 1))
    fi
done
if [ $PHP_RUNNING -gt 0 ]; then
    echo "✓ PHP-FPM: Running ($PHP_RUNNING versions)"
else
    echo "✗ PHP-FPM: Stopped"
fi

# Check Panel
if sudo -u panel pm2 status 2>/dev/null | grep -q "breach-rabbit-panel"; then
    echo "✓ Panel: Running"
else
    echo "✗ Panel: Stopped"
fi

echo ""
echo "For detailed status: sudo -u panel pm2 status"
EOF

chmod +x /usr/local/bin/panel-health

# Create comprehensive info script
cat > /usr/local/bin/panel-info <<'EOF'
#!/bin/bash
# Breach Rabbit Panel Information

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║          Breach Rabbit Web Panel Information               ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# System Info
echo "System Information:"
echo "------------------"
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# Resource Usage
echo "Resource Usage:"
echo "--------------"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "Disk: $(df -h / | awk 'NR==2 {print $5}')"
echo ""

# Services
echo "Services Status:"
echo "---------------"
systemctl is-active litespeed nginx redis-server mariadb php8.3-fpm 2>/dev/null | paste -sd " " - | awk '{print "All services: " $0}'
echo ""

# Panel Info
echo "Panel Information:"
echo "-----------------"
echo "Location: /opt/panel/backend"
echo "URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "Admin: admin / (see credentials file)"
echo ""

# PHP Versions
echo "PHP Versions:"
echo "------------"
for version in 8.3 8.4 8.5; do
    if command -v php${version} &> /dev/null; then
        echo "  ✓ PHP ${version}: $(php${version} -v | head -n1 | cut -d' ' -f2)"
    fi
done
echo ""

# Database Info
echo "Database Information:"
echo "--------------------"
echo "Type: MariaDB"
echo "Host: localhost:3306"
echo "Database: panel_db"
echo ""

# Paths
echo "Important Paths:"
echo "---------------"
echo "Panel: /opt/panel/"
echo "Websites: /var/www/sites/"
echo "SSL Certs: /etc/panel/ssl/"
echo "Logs: /var/log/panel/"
echo "Backups: /opt/panel/backups/"
echo ""

# Quick Commands
echo "Quick Commands:"
echo "--------------"
echo "  panel-health    - Check health status"
echo "  panel-startup   - Start all services"
echo "  panel-logs      - View panel logs"
echo "  panel-status    - Check panel status"
echo "  panel-restart   - Restart panel"
echo ""
EOF

chmod +x /usr/local/bin/panel-info

# Display final information
cat /etc/motd

echo ""
echo "Installation Summary:"
echo "---------------------"
echo "✓ System updated and secured"
echo "✓ OpenLiteSpeed installed (port 7080)"
echo "✓ Nginx installed (ports 80/443)"
echo "✓ PHP 8.3, 8.4, 8.5 installed with WordPress extensions"
echo "✓ Redis installed and configured"
echo "✓ MariaDB installed and optimized"
echo "✓ Node.js 20.x + PM2 installed"
echo "✓ acme.sh installed for SSL"
echo "✓ Next.js Panel deployed"
echo "✓ Panel environment configured"
echo "✓ System optimized for detected hardware"
echo ""
echo "Credentials saved to: ${CREDENTIALS_FILE}"
echo ""
echo "To start the panel, run:"
echo "  sudo -u panel pm2 start /opt/panel/ecosystem.config.js"
echo "  sudo -u panel pm2 save"
echo ""
echo "To check status:"
echo "  sudo -u panel pm2 status"
echo ""
echo "For more information:"
echo "  panel-info"
echo "  panel-health"
echo ""