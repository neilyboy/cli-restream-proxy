# Multi-M3U8 and YouTube Live Stream Proxy

This repository contains two Bash scripts designed to proxy M3U8 IPTV streams and YouTube live streams via Nginx. These scripts are intended for use on Linux systems, including Raspberry Pi.

## Script 1: General Linux Server Script

This script is designed for general Linux servers and provides a basic proxy for both M3U8 IPTV streams and YouTube live streams.

### Features

* **M3U8 IPTV Stream Proxying:** Proxies standard M3U8 IPTV streams via Nginx.
* **YouTube Live Stream Proxying:** Captures and re-encodes YouTube live streams using `yt-dlp` and `ffmpeg`, then serves them as HLS streams through Nginx.
* **Automatic Installation:** Installs Nginx, `yt-dlp`, and `ffmpeg` if they are not already installed.
* **HLS Output:** YouTube live streams are converted to HLS for adaptive bitrate streaming.
* **Background Processing:** YouTube stream processing runs in the background, ensuring continuous streaming.

### Usage

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/neilyboy/cli-restream-proxy.git
    cd cli-restream-proxy
    ```
2.  **Edit the script:**
    * Modify the `STREAMS` array to include your desired M3U8 streams and YouTube live stream URLs.
    * YouTube stream URLs should be formatted as `"stream_name=youtube:youtube_url"`.
    * Adjust the `LISTEN_PORT` and `HLS_DIR` variables as needed.
3.  **Run the script:**
    ```bash
    bash script1.sh
    ```
4.  **Access the streams:**
    * The script will output the URLs for accessing the streams.
    * Use an HLS-compatible player to play the streams.

### Configuration

* **`STREAMS`:** An array of stream configurations. Each entry should be in the format `"stream_name=stream_url"`. For YouTube streams, use `"stream_name=youtube:youtube_url"`.
* **`LISTEN_PORT`:** The port on which Nginx will listen.
* **`HLS_DIR`:** The directory where HLS segments for YouTube streams will be stored.

### Dependencies

* Nginx
* yt-dlp
* ffmpeg

## Script 2: Raspberry Pi Optimized Script

This script is optimized for Raspberry Pi and includes additional configurations for better performance.

### Features

* **All features of Script 1**
* **IPv6 Disabling:** Disables IPv6 at both the system and Nginx levels to improve performance and compatibility.
* **Domain and Base Path Extraction:** Extracts the domain and base path from M3U8 URLs for more robust proxying.
* **SSL Settings and Timeouts:** Includes SSL settings and timeouts for improved reliability.

### Usage

1.  **Clone the repository:**
    ```bash
    git clone [repository_url]
    cd [repository_directory]
    ```
2.  **Edit the script:**
    * Modify the `STREAMS` array to include your desired M3U8 streams and YouTube live stream URLs.
    * YouTube stream URLs should be formatted as `"stream_name=youtube:youtube_url"`.
    * Adjust the `LISTEN_PORT` and `HLS_DIR` variables as needed.
3.  **Run the script:**
    ```bash
    bash script2.sh
    ```
4.  **Access the streams:**
    * The script will output the URLs for accessing the streams.
    * Use an HLS-compatible player to play the streams.

### Configuration

* **`STREAMS`:** An array of stream configurations. Each entry should be in the format `"stream_name=stream_url"`. For YouTube streams, use `"stream_name=youtube:youtube_url"`.
* **`LISTEN_PORT`:** The port on which Nginx will listen.
* **`HLS_DIR`:** The directory where HLS segments for YouTube streams will be stored.

### Dependencies

* Nginx
* yt-dlp
* ffmpeg

### Additional Raspberry Pi Optimizations

* **IPv6 Disabling:** Ensures IPv6 is disabled to reduce potential issues and improve performance on Raspberry Pi.
* **Domain and Base Path Extraction:** Improves proxying of M3U8 streams by dynamically extracting domain and base path information.
* **SSL and Timeout Configuration:** Adds specific configurations for SSL and timeouts to enhance reliability.

## Important Notes

* **Copyright:** Be aware of copyright restrictions. Re-streaming copyrighted content without permission is illegal.
* **Resource Usage:** Live streaming requires significant server resources, including CPU, RAM, and bandwidth. Monitor your server's performance.
* **Latency:** Re-streaming introduces latency. Expect some delay in the streamed content.
* **Error Handling:** Implement error handling and monitoring for production environments.
* **Security:** Secure your Nginx server and restrict access to the streams as needed.
* **Replace Placeholders:** Make sure to replace placeholders like `[repository_url]`, `youtube_url`, `IPTVSTREAMURL.m3u8`, and `YOURIPADDRESSHERE` with your actual values.
* **Testing:** Test thoroughly after making any changes to the scripts or configurations.
