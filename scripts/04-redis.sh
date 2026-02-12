#!/bin/bash
set -e

REDIS_PASS=$1
TOTAL_RAM=$2

echo "Installing Redis..."
apt install -y redis-server > /dev/null 2>&1

# Calculate Redis memory
if [ "$TOTAL_RAM" -lt 2000 ]; then
    REDIS_MEMORY="256mb"
elif [ "$TOTAL_RAM" -lt 4000 ]; then
    REDIS_MEMORY="512mb"
else
    REDIS_MEMORY="1gb"
fi

# Configure Redis
cat > /etc/redis/redis.conf <<EOF
bind 127.0.0.1 ::1
protected-mode yes
port 6379
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16

# Memory
maxmemory ${REDIS_MEMORY}
maxmemory-policy allkeys-lru

# Security
requirepass ${REDIS_PASS}
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG ""

# Persistence
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
dbfilename dump.rdb
dir /var/lib/redis
EOF

mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis
chmod 755 /var/lib/redis

systemctl restart redis-server 2>/dev/null || true
systemctl enable redis-server 2>/dev/null || true
sleep 2

echo "✓ Redis configured (${REDIS_MEMORY})"