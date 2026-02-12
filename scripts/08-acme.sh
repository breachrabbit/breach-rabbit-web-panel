#!/bin/bash
set -e

echo "Installing acme.sh..."
sudo -u panel bash << 'EOF'
cd /home/panel
curl https://get.acme.sh | sh > /dev/null 2>&1
EOF

ln -sf /home/panel/.acme.sh/acme.sh /usr/local/bin/acme.sh 2>/dev/null || true

mkdir -p /etc/panel/ssl
chown panel:www-data /etc/panel/ssl
chmod 750 /etc/panel/ssl

echo "✓ acme.sh installed for SSL management"