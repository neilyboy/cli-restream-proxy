#!/bin/bash
# Configuration
STREAMS=(
  "stream1=https://IPTVSTREAMURL.m3u8"
  "stream2=https://IPTVSTREAMURL.m3u8"
  # Add more streams as needed (stream_name=m3u8_url)
)
LISTEN_PORT=8088

# Update and install nginx
echo "Updating and installing nginx..."
sudo apt update -y
sudo apt install -y nginx

# Create nginx configuration file
CONFIG_FILE="/etc/nginx/sites-available/multi-m3u8-proxy"

# Generate nginx configuration
CONFIG_CONTENT="server {
    listen $LISTEN_PORT;
    resolver 8.8.8.8 ipv6=off;
"

for stream in "${STREAMS[@]}"; do
  stream_name=$(echo "$stream" | cut -d'=' -f1)
  m3u8_url=$(echo "$stream" | cut -d'=' -f2)
  
  # Extract domain and base path from m3u8_url
  domain=$(echo "$m3u8_url" | sed -E 's|https?://([^/]+)/.*|\1|')
  base_path=$(echo "$m3u8_url" | sed -E 's|https?://[^/]+(/.*/).*\.m3u8|\1|')
  
  CONFIG_CONTENT+="
    # Base m3u8 file
    location = /$stream_name/ {
        proxy_pass $m3u8_url;
        proxy_set_header Host $domain;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        
        # SSL settings
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
        proxy_ssl_server_name on;
        
        # Timeouts
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
    
    # Sub-resources (quality variants, subtitles, etc.)
    location ~* ^/$stream_name/(.+)$ {
        proxy_pass https://$domain$base_path\$1;
        proxy_set_header Host $domain;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        
        # SSL settings
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
        proxy_ssl_server_name on;
        
        # Timeouts
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
"
done

CONFIG_CONTENT+="
}"

# Write configuration to file
echo "$CONFIG_CONTENT" | sudo tee "$CONFIG_FILE"

# Enable the configuration and restart nginx
sudo ln -sf "$CONFIG_FILE" /etc/nginx/sites-enabled/multi-m3u8-proxy
sudo systemctl restart nginx

# Disable IPv6 at system level
echo "Ensuring IPv6 is disabled..."
if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
fi

# Disable IPv6 in nginx directly
echo "Disabling IPv6 in nginx..."
if ! grep -q "http::/0" /etc/hosts.deny; then
  echo "http::/0" | sudo tee -a /etc/hosts.deny
fi

echo "m3u8 proxy started on port $LISTEN_PORT"
echo "Access the streams at:"
for stream in "${STREAMS[@]}"; do
  stream_name=$(echo "$stream" | cut -d'=' -f1)
  echo "  http://$(hostname -I | awk '{print $1}'):$LISTEN_PORT/$stream_name/"
done
echo "If the above URL does not work, replace the hostname with the Pi's IP address."
