#!/bin/bash
set -e

MAX_WORKERS=$1

echo "Installing Nginx..."
apt install -y nginx

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Create Nginx configuration for OLS proxy
cat > /etc/nginx/sites-available/ols-proxy <<'EOF'
upstream ols_backend {
    server 127.0.0.1:8088;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Panel access (temporary during setup)
    location /panel/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }

    # Main proxy to OLS
    location / {
        proxy_pass http://ols_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        # Optimized timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        send_timeout 60s;

        # Buffer optimization
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 8 32k;
        proxy_busy_buffers_size 64k;
        proxy_temp_file_write_size 64k;

        # Cache static files
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ols-proxy /etc/nginx/sites-enabled/

# Create optimized nginx.conf
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

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript 
               application/xml+rss application/javascript application/json 
               application/rss+xml application/atom+xml image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Test and reload Nginx
nginx -t && systemctl reload nginx
systemctl enable nginx

echo "✓ Nginx installed and configured"
echo "  Proxying to OLS on port 8088"
echo "  Panel accessible at /panel/ (temporary)"