#!/bin/bash

# Configuration
STREAMS=(
    "streamname1=https://STREAMURL.m3u8"
    "streamname2=https://STREAMURL.m3u8"
    "youtubestream1=youtube:https://www.youtube.com/watch?v=YOUR_YOUTUBE_VIDEO_ID" #youtube stream
    # Add more streams as needed (stream_name=m3u8_url or stream_name=youtube:youtube_url)
)

LISTEN_PORT=8088
HLS_DIR="/tmp/live_streams" # Directory to store HLS segments

# Install necessary tools
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

if ! command -v yt-dlp &> /dev/null; then
    echo "Installing yt-dlp..."
    sudo apt install -y yt-dlp
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg..."
    sudo apt install -y ffmpeg
fi

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
        CONFIG_CONTENT+="
        location /$stream_name/ {
            proxy_pass $stream_url;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_buffering off;
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

echo "m3u8 proxy started on port $LISTEN_PORT"
echo "Access the streams at:"

for stream in "${STREAMS[@]}"; do
    stream_name=$(echo "$stream" | cut -d'=' -f1)
    echo "    http://YOURIPADDRESSHERE:$LISTEN_PORT/$stream_name/"
done
