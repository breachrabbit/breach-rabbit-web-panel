#!/bin/bash
set -e

CONFIG_PROFILE=$1
TOTAL_RAM=$2
CPU_COUNT=$3
MAX_WORKERS=$4
PHP_MEMORY=$5
MYSQL_BUFFER=$6

echo "Optimizing system for ${CONFIG_PROFILE} profile..."

# OLS Optimization
echo "Optimizing OpenLiteSpeed..."
cat > /usr/local/lsws/conf/httpd_config.conf <<EOF
serverName                  $(hostname)
user                        nobody
group                       nogroup
priority                    0
autoRestart                 1
chrootPath                  /usr/local/lsws
enableChroot                0
inMemBufSize                4096
swappingDir                 /tmp/lshttpd/swap
autoFix503                  1
gracefulRestartTimeout      300

# Connection limits based on profile
maxConnections              $((MAX_WORKERS * 200))
maxSSLConnections           $((MAX_WORKERS * 100))
connTimeout                 300
maxKeepAliveReq             1000
smartKeepAlive              1
keepAliveTimeout            5
sndBufSize                  0
rcvBufSize                  0
maxReqURLLen                8192
maxReqHeaderSize            16380
maxReqBodySize              2047
maxDynRespHeaderSize        8192
maxDynRespSize              209715200
enableGzipCompress          1
enableDynGzipCompress       1
gzipCompressLevel           6
gzipAutoUpdateStatic        1
gzipMinFileSize             300
gzipMaxFileSize             1048576

# Worker processes based on CPU cores
workers                     ${MAX_WORKERS}

# Event loop
eventLoopLimit              5000

# Security
disableInitLogRotation      0
enableLVE                   0
cloudLinux                  0

# HTTP/2 and HTTP/3
enableH2c                   1
enableH2                    1
enableQuic                  0

# Modules
module default {
  lsapiApp
}

vhFile                      conf/vhosts/vhconf.conf
EOF

# PHP Optimization for all versions
for PHP_VERSION in "8.3" "8.4" "8.5"; do
    echo "Optimizing PHP ${PHP_VERSION}..."
    
    cat > /etc/php/${PHP_VERSION}/fpm/php.ini <<EOF
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source
disable_classes =
zend.enable_gc = On
expose_php = Off

max_execution_time = 300
max_input_time = 600
memory_limit = ${PHP_MEMORY}M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php${PHP_VERSION}-fpm.log
post_max_size = 64M
default_mimetype = "text/html"
default_charset = "UTF-8"
enable_dl = Off

file_uploads = On
upload_max_filesize = 64M
max_file_uploads = 20

allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[Date]
date.timezone = UTC

[Session]
session.save_handler = files
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly = 1
session.cookie_samesite = Strict
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5
session.upload_progress.enabled = On
session.upload_progress.cleanup = On
session.upload_progress.prefix = "upload_progress_"
session.upload_progress.name = "PHP_SESSION_UPLOAD_PROGRESS"
session.upload_progress.freq = "1%"
session.upload_progress.min_freq = "1"
session.lazy_write = On

[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.enable_cli=1
opcache.jit_buffer_size=64M
opcache.jit=1235
EOF

    # PHP-FPM pool optimization
    cat > /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf <<EOF
[www]
user = www-data
group = www-data
listen = /run/php/php${PHP_VERSION}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = $((MAX_WORKERS * 10))
pm.start_servers = $((MAX_WORKERS * 2))
pm.min_spare_servers = $((MAX_WORKERS * 1))
pm.max_spare_servers = $((MAX_WORKERS * 4))
pm.max_requests = 500

pm.status_path = /status
ping.path = /ping
ping.response = pong

access.log = /var/log/php${PHP_VERSION}-fpm-access.log
slowlog = /var/log/php${PHP_VERSION}-fpm-slow.log
request_slowlog_timeout = 5s
request_terminate_timeout = 300s

security.limit_extensions = .php

env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF
done

# Nginx optimization
echo "Optimizing Nginx..."
cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes ${MAX_WORKERS};
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript 
               application/xml+rss application/javascript application/json 
               application/rss+xml application/atom+xml image/svg+xml;

    # FastCGI cache
    fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";
    fastcgi_cache_use_stale error timeout invalid_header http_500;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create Nginx cache directory
mkdir -p /var/cache/nginx
chown www-data:www-data /var/cache/nginx
chmod 755 /var/cache/nginx

# Redis optimization
echo "Optimizing Redis..."
REDIS_MEMORY=$(awk "BEGIN {if(${TOTAL_RAM}<2000) print \"256mb\"; else if(${TOTAL_RAM}<4000) print \"512mb\"; else if(${TOTAL_RAM}<8000) print \"1gb\"; else print \"2gb\"}")
sed -i "s/maxmemory .*/maxmemory ${REDIS_MEMORY}/" /etc/redis/redis.conf
sed -i "s/maxmemory-policy .*/maxmemory-policy allkeys-lru/" /etc/redis/redis.conf

# System limits optimization
echo "Optimizing system limits..."
cat > /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
www-data soft nofile 65535
www-data hard nofile 65535
www-data soft nproc 65535
www-data hard nproc 65535
panel soft nofile 65535
panel hard nofile 65535
panel soft nproc 65535
panel hard nproc 65535
EOF

# Create systemd override for file limits
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/limits.conf <<EOF
[Service]
LimitNOFILE=65535
LimitNPROC=65535
EOF

mkdir -p /etc/systemd/system/redis-server.service.d
cat > /etc/systemd/system/redis-server.service.d/limits.conf <<EOF
[Service]
LimitNOFILE=65535
LimitNPROC=65535
EOF

# Reload systemd
systemctl daemon-reload

# Restart all services
echo "Restarting services..."
systemctl restart litespeed
systemctl restart nginx
systemctl restart redis-server
systemctl restart php8.3-fpm php8.4-fpm php8.5-fpm
systemctl restart mariadb

echo "✓ System optimized for ${CONFIG_PROFILE} profile"
echo "  Workers: ${MAX_WORKERS}"
echo "  PHP Memory: ${PHP_MEMORY}M"
echo "  MySQL Buffer: ${MYSQL_BUFFER}M"