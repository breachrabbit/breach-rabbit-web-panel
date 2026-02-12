#!/bin/bash
set -e

echo "Installing Node.js 20.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs build-essential

# Install PM2 globally
echo "Installing PM2 process manager..."
npm install -g pm2

# Setup PM2 startup
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u panel --hp /home/panel

# Install Yarn
echo "Installing Yarn package manager..."
npm install -g yarn

# Install additional global tools
echo "Installing additional tools..."
npm install -g nodemon typescript

echo "✓ Node.js 20.x and PM2 installed"
echo "  Node version: $(node -v)"
echo "  NPM version: $(npm -v)"
echo "  PM2 version: $(pm2 -v)"