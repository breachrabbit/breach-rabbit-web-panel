#!/bin/bash
set -e

REDIS_PASSWORD=$1
TOTAL_RAM=$2

echo "Installing Redis..."
apt install -y redis-server

# Calculate Redis maxmemory based on available RAM
if [ "$TOTAL_RAM" -lt 2000 ]; then
    REDIS_MEMORY="256mb"
elif [ "$TOTAL_RAM" -lt 4000 ]; then
    REDIS_MEMORY="512mb"
elif [ "$TOTAL_RAM" -lt 8000 ]; then
    REDIS_MEMORY="1gb"
else
    REDIS_MEMORY="2gb"
fi

echo "Configuring Redis (maxmemory: ${REDIS_MEMORY})..."

# Backup original config
cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

# Configure Redis
cat > /etc/redis/redis.conf <<EOF
# Redis configuration file
bind 127.0.0.1 ::1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
always-show-logo no

# Memory optimization
maxmemory ${REDIS_MEMORY}
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Security
requirepass ${REDIS_PASSWORD}
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes

# Replication
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100

# Security hardening
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG ""

# Performance
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
EOF

# Create Redis data directory
mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis
chmod 755 /var/lib/redis

# Enable and restart Redis
systemctl enable redis-server
systemctl restart redis-server

# Wait for Redis to start
sleep 3

# Test Redis connection
if redis-cli -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q "PONG"; then
    echo "✓ Redis installed and configured"
    echo "  Host: localhost"
    echo "  Port: 6379"
    echo "  Max Memory: ${REDIS_MEMORY}"
else
    echo "⚠️  Warning: Could not verify Redis connection"
fi