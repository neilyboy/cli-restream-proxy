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
"

for stream in "${STREAMS[@]}"; do
  stream_name=$(echo "$stream" | cut -d'=' -f1)
  m3u8_url=$(echo "$stream" | cut -d'=' -f2)

  CONFIG_CONTENT+="
    location /$stream_name/ {
        proxy_pass $m3u8_url;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
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

echo "m3u8 proxy started on port $LISTEN_PORT"
echo "Access the streams at:"

for stream in "${STREAMS[@]}"; do
  stream_name=$(echo "$stream" | cut -d'=' -f1)
  echo "  http://YOURIPADDRESSHERE:$LISTEN_PORT/$stream_name/"
done
