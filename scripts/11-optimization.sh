#!/bin/bash
set -e

PROFILE=$1
TOTAL_RAM=$2
CPU_COUNT=$3
WORKERS=$4
PHP_MEMORY=$5
MYSQL_BUFFER=$6

echo "Optimizing for ${PROFILE} profile..."

# OLS optimization
cat > /usr/local/lsws/conf/httpd_config.conf <<EOF
serverName $(hostname)
user nobody
group nogroup
maxConnections $((WORKERS * 200))
maxSSLConnections $((WORKERS * 100))
connTimeout 300
keepAliveTimeout 5
enableGzipCompress 1
workers ${WORKERS}
vhFile conf/vhosts/vhconf.conf
EOF

# PHP optimization
for ver in 8.3 8.4 8.5; do
    sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY}M/" /etc/php/$ver/fpm/php.ini 2>/dev/null || true
done

# Redis memory
REDIS_MEM=$(awk "BEGIN {print (${TOTAL_RAM}<2000)?\"256mb\":(${TOTAL_RAM}<4000)?\"512mb\":\"1gb\"}")
sed -i "s/maxmemory .*/maxmemory ${REDIS_MEM}/" /etc/redis/redis.conf 2>/dev/null || true

# System limits
cat > /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
www-data soft nofile 65535
www-data hard nofile 65535
panel soft nofile 65535
panel hard nofile 65535
EOF

systemctl daemon-reexec
systemctl restart litespeed nginx redis-server php8.3-fpm php8.4-fpm php8.5-fpm mariadb 2>/dev/null || true

echo "✓ System optimized for ${PROFILE} profile"