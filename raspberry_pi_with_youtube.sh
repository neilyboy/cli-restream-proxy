#!/bin/bash

# Configuration
STREAMS=(
    "stream1=https://IPTVSTREAMURL.m3u8"
    "stream2=https://IPTVSTREAMURL.m3u8"
    "youtubestream1=youtube:https://www.youtube.com/watch?v=YOUR_YOUTUBE_VIDEO_ID" # Example youtube stream
    # Add more streams as needed (stream_name=m3u8_url or stream_name=youtube:youtube_url)
)
LISTEN_PORT=8088
HLS_DIR="/tmp/live_streams" # Directory to store HLS segments

# Update and install nginx, yt-dlp, ffmpeg
echo "Updating and installing nginx, yt-dlp, ffmpeg..."
sudo apt update -y
sudo apt install -y nginx yt-dlp ffmpeg

# Create HLS directory if it doesn't exist
mkdir -p "$HLS_DIR"

# Function to handle YouTube streams
handle_youtube_stream() {
    local stream_name="$1"
    local youtube_url="$2"
    local hls_path="$HLS_DIR/$stream_name"
    mkdir -p "$hls_path"

    while true; do
        local live_url=$(yt-dlp -g "$youtube_url")
        if [[ -z "$live_url" ]]; then
            echo "Failed to get live stream URL for $stream_name. Retrying in 10 seconds..."
            sleep 10
            continue
        fi

        ffmpeg -i "$live_url" -codec copy -hls_time 10 -hls_list_size 0 -hls_segment_filename "$hls_path/segment_%03d.ts" "$hls_path/index.m3u8" -y
        # if ffmpeg fails, this loop will restart.
        echo "ffmpeg process for $stream_name exited. Restarting..."
        sleep 5
    done
}

# Create nginx configuration file
CONFIG_FILE="/etc/nginx/sites-available/multi-m3u8-proxy"

# Generate nginx configuration
CONFIG_CONTENT="server {
    listen $LISTEN_PORT;
    resolver 8.8.8.8 ipv6=off;
"

for stream in "${STREAMS[@]}"; do
    stream_name=$(echo "$stream" | cut -d'=' -f1)
    stream_url=$(echo "$stream" | cut -d'=' -f2)

    if [[ "$stream_url" == "youtube:"* ]]; then
        youtube_url=$(echo "$stream_url" | cut -d':' -f2-)
        handle_youtube_stream "$stream_name" "$youtube_url" & # Run in background
        CONFIG_CONTENT+="
        location /$stream_name/ {
            alias $HLS_DIR/$stream_name/;
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            add_header Cache-Control no-cache;
        }
        "
    else
        domain=$(echo "$stream_url" | sed -E 's|https?://([^/]+)/.*|\1|')
        base_path=$(echo "$stream_url" | sed -E 's|https?://[^/]+(/.*/).*\.m3u8|\1|')

        CONFIG_CONTENT+="
        # Base m3u8 file
        location = /$stream_name/ {
            proxy_pass $stream_url;
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
    fi
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
    echo "    http://$(hostname -I | awk '{print $1}'):$LISTEN_PORT/$stream_name/"
done
echo "If the above URL does not work, replace the hostname with the Pi's IP address."
