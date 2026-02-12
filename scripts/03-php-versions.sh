#!/bin/bash
set -e

PHP_MEMORY=$1

echo "Adding PHP repository..."
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt update > /dev/null 2>&1

echo "Installing PHP 8.3, 8.4, 8.5 with WordPress extensions..."

# Install all versions with WP extensions
for ver in 8.3 8.4 8.5; do
    apt install -y php${ver} php${ver}-fpm php${ver}-cli php${ver}-common \
        php${ver}-mysql php${ver}-curl php${ver}-gd php${ver}-intl php${ver}-mbstring \
        php${ver}-xml php${ver}-zip php${ver}-bcmath php${ver}-imagick php${ver}-opcache \
        php${ver}-redis php${ver}-soap > /dev/null 2>&1
done

# Configure PHP
for ver in 8.3 8.4 8.5; do
    cat > /etc/php/$ver/fpm/php.ini <<EOF
memory_limit = ${PHP_MEMORY}M
max_execution_time = 300
max_input_time = 600
upload_max_filesize = 64M
post_max_size = 64M
expose_php = Off
date.timezone = UTC
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
EOF

    cat > /etc/php/$ver/fpm/pool.d/www.conf <<EOF
[www]
user = www-data
group = www-data
listen = /run/php/php${ver}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 500
EOF
done

# Restart PHP-FPM
systemctl restart php8.3-fpm php8.4-fpm php8.5-fpm 2>/dev/null || true
systemctl enable php8.3-fpm php8.4-fpm php8.5-fpm 2>/dev/null || true

echo "✓ PHP 8.3/8.4/8.5 installed with WordPress extensions"