#!/bin/bash
set -e

DB_PASSWORD=$1
DB_ROOT_PASSWORD=$2
MYSQL_BUFFER=$3

echo "Installing MariaDB..."
apt install -y mariadb-server

# Secure MariaDB installation
mysql_secure_installation <<EOF

n
y
${DB_ROOT_PASSWORD}
${DB_ROOT_PASSWORD}
y
y
y
y
EOF

# Create panel database and user
mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS panel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'panel_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON panel_db.* TO 'panel_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Optimize MariaDB configuration
cat > /etc/mysql/mariadb.conf.d/99-breach-rabbit.cnf <<EOF
[mysqld]
# Basic settings
user            = mysql
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
port            = 3306
basedir         = /usr
datadir         = /var/lib/mysql
tmpdir          = /tmp
lc-messages-dir = /usr/share/mysql
skip-external-locking

# Memory optimization based on detected RAM
innodb_buffer_pool_size = ${MYSQL_BUFFER}M
innodb_log_file_size = $((${MYSQL_BUFFER} / 4))M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1

# Connection limits
max_connections = 100
thread_cache_size = 16
table_open_cache = 512
table_definition_cache = 256

# Query cache (disabled for better performance)
query_cache_type = 0
query_cache_size = 0

# Performance
skip-name-resolve
performance_schema = 0
symbolic-links = 0

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_error = /var/log/mysql/error.log

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysqldump]
quick
quote-names
max_allowed_packet = 64M

[mysql]
default-character-set = utf8mb4

[isamchk]
key_buffer_size = 16M
EOF

# Create slow query log directory
mkdir -p /var/log/mysql
touch /var/log/mysql/slow.log /var/log/mysql/error.log
chown mysql:mysql /var/log/mysql/*.log

# Restart MariaDB
systemctl restart mariadb
systemctl enable mariadb

# Test database connection
if mysql -u panel_user -p"${DB_PASSWORD}" -e "SELECT 1" panel_db 2>/dev/null; then
    echo "✓ MariaDB installed and optimized"
    echo "  Database: panel_db"
    echo "  User: panel_user"
else
    echo "⚠️  Warning: Could not verify database connection"
fi