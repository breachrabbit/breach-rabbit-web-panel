# 🐰 Breach Rabbit Web Panel

**Lightweight, self-hosted web panel optimized for 1 Core / 2GB RAM**

Modern alternative to aaPanel/cPanel built on OpenLiteSpeed + Next.js

---

## 🚀 Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/breachrabbit/breach-rabbit-web-panel/main/install.sh | sudo bash

Or clone and run:

```bash
git clone https://github.com/breachrabbit/breach-rabbit-web-panel.git
cd breach-rabbit-web-panel
sudo bash install.sh

📋 Requirements
OS: Ubuntu 22.04 / Debian 11+
CPU: 1 Core (minimum)
RAM: 2GB (minimum)
Disk: 10GB+ free space
Root access

🏗️ Architecture
```bash
┌─────────────────────────────────────────┐
│         Next.js Frontend (UI)           │
│         Port: 3000                      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Next.js API Routes              │
│  - OLS API Proxy                        │
│  - Aeza API Integration                 │
│  - Backup Management                    │
│  - Firewall Control                     │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│         Server Services                  │
│  ├─ OpenLiteSpeed (8088)                │
│  ├─ Nginx (80/443)                      │
│  ├─ MariaDB                             │
│  ├─ acme.sh (SSL)                       │
│  └─ PM2 (Process Manager)               │
└─────────────────────────────────────────┘

✨ Features
Core Features (MVP v1)
✅ Website Management - Create, delete, manage sites via OLS API
✅ SSL Manager - Auto SSL with acme.sh, expiry tracking
✅ Reverse Proxy - Docker container proxy, custom backends
✅ Database Manager - MariaDB/PostgreSQL with Adminer
✅ File Manager - Upload, edit, manage files (FileBrowser)
✅ Backup System - Restic-based backups with retention policies
✅ Firewall GUI - Manage ports, IP whitelist/blacklist
✅ Cron Manager - Schedule and manage cron jobs
✅ Log Viewer - Real-time log monitoring
✅ Web Terminal - Built-in terminal access
✅ Server Monitoring - CPU, RAM, Disk, Network stats

Planned (v2+)
🚧 Client accounts with RBAC
🚧 Docker container management
🚧 Uptime monitoring
🚧 DNS management
🚧 CDN integration
🚧 Billing system

📁 Installation Structure
After installation, you'll have:
```bash
/opt/panel/
├── backend/          # Next.js API + Frontend
├── frontend/         # Built frontend (optional)
├── logs/            # Panel logs
└── backups/         # Backup storage

/var/www/sites/      # Website root directories

/etc/panel/
├── ssl/            # SSL certificates
└── ols-api.key     # OLS API credentials

/var/log/panel/      # Runtime logs
