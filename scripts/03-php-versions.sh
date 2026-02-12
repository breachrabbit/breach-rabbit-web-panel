#!/bin/bash
set -e

PHP_MEMORY=$1
CONFIG_PROFILE=$2

echo "Installing PHP repository..."
apt install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt update

echo "Installing PHP 8.3, 8.4, 8.5 with WordPress extensions..."

# Install PHP 8.3
echo "Installing PHP 8.3..."
apt install -y php8.3 php8.3-fpm php8.3-cli php8.3-common \
    php8.3-mysql php8.3-curl php8.3-gd php8.3-intl php8.3-mbstring \
    php8.3-xml php8.3-zip php8.3-bcmath php8.3-imagick php8.3-opcache \
    php8.3-redis php8.3-soap php8.3-xmlrpc php8.3-xsl php8.3-json

# Install PHP 8.4
echo "Installing PHP 8.4..."
apt install -y php8.4 php8.4-fpm php8.4-cli php8.4-common \
    php8.4-mysql php8.4-curl php8.4-gd php8.4-intl php8.4-mbstring \
    php8.4-xml php8.4-zip php8.4-bcmath php8.4-imagick php8.4-opcache \
    php8.4-redis php8.4-soap php8.4-xmlrpc php8.4-xsl php8.4-json

# Install PHP 8.5
echo "Installing PHP 8.5..."
apt install -y php8.5 php8.5-fpm php8.5-cli php8.5-common \
    php8.5-mysql php8.5-curl php8.5-gd php8.5-intl php8.5-mbstring \
    php8.5-xml php8.5-zip php8.5-bcmath php8.5-imagick php8.5-opcache \
    php8.5-redis php8.5-soap php8.5-xmlrpc php8.5-xsl php8.5-json

# Configure PHP 8.3 for WordPress
echo "Configuring PHP 8.3..."
cat > /etc/php/8.3/fpm/php.ini <<EOF
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1
disable_functions =
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
error_log = /var/log/php8.3-fpm.log
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

[CLI Server]
cli_server.color = On

[Date]
date.timezone = UTC

[Filter]

[iconv]

[intl]

[sqlite3]

[Pcre]

[Pdo]

[Pdo_mysql]
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=

[Phar]

[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = Off

[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1

[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"

[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[OCI8]

[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[bcmath]
bcmath.scale = 0

[browscap]

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
session.referer_check =
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

[Assertion]

[COM]

[mbstring]

[gd]

[exif]

[Tidy]
tidy.clean_output = Off

[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5

[ldap]
ldap.max_links = -1

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

# Configure PHP 8.4
cp /etc/php/8.3/fpm/php.ini /etc/php/8.4/fpm/php.ini

# Configure PHP 8.5
cp /etc/php/8.3/fpm/php.ini /etc/php/8.5/fpm/php.ini

# Restart PHP-FPM services
systemctl restart php8.3-fpm php8.4-fpm php8.5-fpm
systemctl enable php8.3-fpm php8.4-fpm php8.5-fpm

# Create PHP version selector script
cat > /usr/local/bin/php-select <<'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: php-select <version>"
    echo "Available versions: 8.3, 8.4, 8.5"
    exit 1
fi

case $1 in
    8.3)
        update-alternatives --set php /usr/bin/php8.3
        update-alternatives --set phar /usr/bin/phar8.3
        update-alternatives --set phar.phar /usr/bin/phar.phar8.3
        ;;
    8.4)
        update-alternatives --set php /usr/bin/php8.4
        update-alternatives --set phar /usr/bin/phar8.4
        update-alternatives --set phar.phar /usr/bin/phar.phar8.4
        ;;
    8.5)
        update-alternatives --set php /usr/bin/php8.5
        update-alternatives --set phar /usr/bin/phar8.5
        update-alternatives --set phar.phar /usr/bin/phar.phar8.5
        ;;
    *)
        echo "Invalid version: $1"
        exit 1
        ;;
esac

echo "PHP version switched to $1"
php -v
EOF

chmod +x /usr/local/bin/php-select

echo "✓ PHP 8.3, 8.4, 8.5 installed with WordPress extensions"
echo "  Use 'php-select 8.3|8.4|8.5' to switch versions"