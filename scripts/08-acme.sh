#!/bin/bash
set -e

echo "Installing acme.sh for SSL certificates..."

# Install as panel user
sudo -u panel bash << 'EOF'
cd /home/panel

# Install acme.sh
curl https://get.acme.sh | sh

# Create SSL directory
mkdir -p /home/panel/.acme.sh
EOF

# Create SSL storage directory
mkdir -p /etc/panel/ssl
chown panel:www-data /etc/panel/ssl
chmod 750 /etc/panel/ssl

# Add acme.sh to PATH
if [ ! -f /usr/local/bin/acme.sh ]; then
    ln -sf /home/panel/.acme.sh/acme.sh /usr/local/bin/acme.sh
fi

# Create SSL management script
cat > /usr/local/bin/panel-ssl <<'EOF'
#!/bin/bash
# SSL Management Script for Breach Rabbit Panel

SSL_DIR="/etc/panel/ssl"
ACME_HOME="/home/panel/.acme.sh"

case "$1" in
    issue)
        if [ -z "$2" ]; then
            echo "Usage: panel-ssl issue <domain>"
            exit 1
        fi
        DOMAIN=$2
        sudo -u panel /home/panel/.acme.sh/acme.sh --issue -d "$DOMAIN" --webroot /var/www/html
        ;;
    install)
        if [ -z "$2" ]; then
            echo "Usage: panel-ssl install <domain>"
            exit 1
        fi
        DOMAIN=$2
        sudo -u panel /home/panel/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
            --key-file "$SSL_DIR/$DOMAIN.key" \
            --fullchain-file "$SSL_DIR/$DOMAIN.crt" \
            --reloadcmd "systemctl reload nginx"
        ;;
    renew)
        sudo -u panel /home/panel/.acme.sh/acme.sh --renew-all
        systemctl reload nginx
        ;;
    list)
        sudo -u panel /home/panel/.acme.sh/acme.sh --list
        ;;
    *)
        echo "Usage: panel-ssl {issue|install|renew|list} [domain]"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/panel-ssl

echo "✓ acme.sh installed for SSL management"
echo "  SSL directory: /etc/panel/ssl"
echo "  Use 'panel-ssl' command to manage certificates"