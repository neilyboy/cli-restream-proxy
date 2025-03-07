#!/bin/bash
# Configuration
STREAMS=(
  "streamname1=https://STREAMURL.m3u8"
  "streamname2=https://STREAMURL.m3u8"
  # Add more streams as needed (stream_name=m3u8_url)
)
LISTEN_PORT=8088

# Install nginx if not already installed
if ! command -v nginx &> /dev/null; then
  echo "Installing nginx..."
  sudo apt update
  sudo apt install -y nginx
fi

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

# Disable IPv6 if needed
echo "Ensuring IPv6 is disabled..."
if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
fi

# Get server IP address using multiple methods for reliability
get_ip_address() {
  # Try hostname -I first (works on most Linux systems)
  local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  
  # If that failed, try ip command
  if [ -z "$ip" ]; then
    ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
  fi
  
  # If that failed too, try ifconfig
  if [ -z "$ip" ]; then
    ip=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v "127.0.0.1" | head -n 1)
  fi
  
  # As a last resort, try to query external service
  if [ -z "$ip" ]; then
    ip=$(curl -s http://ifconfig.me || wget -qO- http://ifconfig.me)
  fi
  
  echo "$ip"
}

SERVER_IP=$(get_ip_address)

echo "m3u8 proxy started on port $LISTEN_PORT"
echo "Access the streams at:"
for stream in "${STREAMS[@]}"; do
  stream_name=$(echo "$stream" | cut -d'=' -f1)
  echo "  http://$SERVER_IP:$LISTEN_PORT/$stream_name/"
done
