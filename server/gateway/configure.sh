#!/bin/sh
# Writes the NGINX configuration from the environment, when the container starts.
#   WEB_ENABLED      true: also serve the web application
#   TRUSTED_PROXIES  addresses (CIDR, separated by spaces) of the reverse proxies
#                    placed in front of this one, whose X-Forwarded-For is trusted
set -eu

conf=/etc/nginx/conf.d/default.conf
root=/usr/share/timelog

real_ip=""
for cidr in ${TRUSTED_PROXIES:-}; do
  real_ip="${real_ip}    set_real_ip_from ${cidr};
"
done
if [ -n "$real_ip" ]; then
  real_ip="${real_ip}    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
"
fi

if [ "${WEB_ENABLED:-false}" = "true" ] && [ ! -f "$root/index.html" ]; then
  echo "timelog: WEB_ENABLED=true but this image has no web application: run 'docker compose up -d --build'" >&2
fi

if [ "${WEB_ENABLED:-false}" = "true" ] && [ -f "$root/index.html" ]; then
  echo "timelog: web application enabled"
  site="    location / {
        root $root;
        try_files \$uri /index.html;
        # The files have no version in their name: always check for a new one.
        add_header Cache-Control \"no-cache\";
        add_header X-Content-Type-Options \"nosniff\";
        add_header X-Frame-Options \"DENY\";
        add_header Referrer-Policy \"same-origin\";
        gzip on;
        gzip_min_length 1024;
        gzip_types application/javascript text/javascript application/wasm application/json text/css font/ttf;
    }"
else
  echo "timelog: web application disabled (API only)"
  site="    location / {
        default_type application/json;
        return 404 '{\"error\":\"not_found\"}';
    }"
fi

cat > "$conf" <<NGINX
server {
    listen 8080;
    server_tokens off;
${real_ip}
    # Docker DNS: the API is found again when its container is recreated.
    resolver 127.0.0.11 valid=10s ipv6=off;

    # The size of a request is checked by the API (MAX_BODY_MB), with an
    # error code that the application understands.
    client_max_body_size 0;
    client_body_timeout 300s;
    send_timeout 300s;

    location /api/ {
        set \$api http://api:8080;
        proxy_pass \$api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        # Replaced, not appended: a client cannot choose the address used
        # by the API to limit the login attempts.
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_request_buffering off;
        proxy_connect_timeout 10s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        error_page 502 504 = @api_unavailable;
    }

    # In JSON like the other errors of the API: the application stays "offline".
    location @api_unavailable {
        default_type application/json;
        return 503 '{"error":"server_unavailable"}';
    }

    location = /gateway-health {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }

$site
}
NGINX
