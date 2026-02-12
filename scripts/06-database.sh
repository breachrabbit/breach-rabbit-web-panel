#!/bin/bash
set -e

DB_PASS=$1
DB_ROOT_PASS=$2
MYSQL_BUFFER=$3

echo "Installing MariaDB..."
apt install -y mariadb-server > /dev/null 2>&1

# Secure installation
mysql_secure_installation <<EOF >/dev/null 2>&1

n
y
${DB_ROOT_PASS}
${DB_ROOT_PASS}
y
y
y
y
EOF

# Create panel database
mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS panel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'panel_user'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON panel_db.* TO 'panel_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# SAFE optimization (NO innodb_log_file_size changes)
cat > /etc/mysql/mariadb.conf.d/99-breach-rabbit.cnf <<EOF
[mysqld]
innodb_buffer_pool_size = ${MYSQL_BUFFER}M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
max_connections = 50
thread_cache_size = 8
table_open_cache = 256
query_cache_type = 0
query_cache_size = 0
skip-name-resolve
performance_schema = 0
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF

mkdir -p /var/log/mysql
touch /var/log/mysql/slow.log /var/log/mysql/error.log
chown mysql:mysql /var/log/mysql/*.log

systemctl restart mariadb 2>/dev/null || true
systemctl enable mariadb 2>/dev/null || true
sleep 2

echo "✓ MariaDB installed and optimized"