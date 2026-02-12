#!/bin/bash
set -e

echo "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -s - > /dev/null 2>&1
apt install -y nodejs > /dev/null 2>&1

echo "Installing PM2..."
npm install -g pm2 yarn > /dev/null 2>&1

# PM2 startup
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u panel --hp /home/panel 2>&1 | grep -v "deprecated" || true

echo "✓ Node.js 20.x and PM2 installed"