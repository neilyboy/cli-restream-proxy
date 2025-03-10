#!/bin/bash

INPUT="$1"
STREAMNAME="$2"
OUTPUT_DIR="/var/www/html/local_streams/$STREAMNAME" #Nginx document root.
CONFIG_FILE="/etc/nginx/sites-available/local-video-proxy"

# Check input
if [[ -z "$INPUT" || -z "$STREAMNAME" ]]; then
    echo "Usage: $0 <file_or_directory> <stream_name>"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process file or directory
if [[ -f "$INPUT" ]]; then
    ffmpeg -i "$INPUT" -codec copy -hls_time 10 -hls_list_size 0 -hls_segment_filename "$OUTPUT_DIR/segment_%03d.ts" "$OUTPUT_DIR/index.m3u8" -y
elif [[ -d "$INPUT" ]]; then
    for file in "$INPUT"/*; do
        if [[ -f "$file" ]]; then
            ffmpeg -i "$file" -codec copy -hls_time 10 -hls_list_size 0 -hls_segment_filename "$OUTPUT_DIR/segment_%03d.ts" "$OUTPUT_DIR/index.m3u8" -y
        fi
    done
else
    echo "Invalid input: $INPUT"
    exit 1
fi

# Nginx configuration
CONFIG_CONTENT="
location /$STREAMNAME/ {
    alias $OUTPUT_DIR/;
    types {
        application/vnd.apple.mpegurl m3u8;
        video/mp2t ts;
    }
    add_header Cache-Control no-cache;
}
"

# Append configuration to existing file.
echo "$CONFIG_CONTENT" | sudo tee -a "$CONFIG_FILE"

# Enable configuration and restart nginx
sudo ln -sf "$CONFIG_FILE" /etc/nginx/sites-enabled/local-video-proxy
sudo systemctl restart nginx

echo "Stream available at: http://$(hostname -I | awk '{print $1}'):8088/$STREAMNAME/index.m3u8"
