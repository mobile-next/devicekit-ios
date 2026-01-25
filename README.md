# DeviceKit iOS

DeviceKit iOS is a UI automation and screen streaming framework for iOS devices. It provides:

- **UI Automation**: JSON-RPC 2.0 API for programmatic device control (port 12004)
- **Screen Streaming**: Real-time H.264 video streaming over TCP (port 12005)

---

## Table of Contents

- [Quick Start](#quick-start)
- [Port Forwarding (iproxy)](#port-forwarding-iproxy)
- [JSON-RPC 2.0 API](#json-rpc-20-api)
  - [Server Configuration](#server-configuration)
  - [Available Methods](#available-methods)
- [API Reference](#api-reference)
  - [io_tap](#io_tap)
  - [io_longpress](#io_longpress)
  - [io_swipe](#io_swipe)
  - [io_text](#io_text)
  - [io_gesture](#io_gesture)
  - [dump_ui](#dump_ui)
  - [screenshot](#screenshot)
  - [apps_launch](#apps_launch)
  - [url](#url)
- [WebSocket Examples](#websocket-examples)
- [Error Codes](#json-rpc-error-codes)
- [Screen Streaming](#screen-streaming)
  - [screencapture.sh](#quick-start-screencapturesh-recommended)
- [Building](#building)

---

## Quick Start

1. Build and run the XCUITest runner on your iOS device/simulator
2. **For real devices**: Set up port forwarding with `iproxy` (see [Port Forwarding](#port-forwarding-iproxy))
3. The JSON-RPC server starts automatically on `127.0.0.1:12004`
4. Send commands via HTTP POST or WebSocket

```bash
# Test connectivity
curl http://127.0.0.1:12004/health

# Tap at coordinates (200, 400)
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_tap","params":{"deviceId":"","x":200,"y":400},"id":1}'
```

---

## Port Forwarding (iproxy)

> **Important**: When running on a **real iOS device**, you must set up USB port forwarding to access the server from your host machine. The server binds to `127.0.0.1` on the device, which is not directly accessible over the network.

### Why Port Forwarding?

- **Simulators**: Work directly with `localhost:12004` - no setup needed
- **Real Devices**: Require USB port forwarding via `iproxy` to tunnel traffic

### Install iproxy

`iproxy` is part of [libimobiledevice](https://libimobiledevice.org/):

```bash
# macOS (Homebrew)
brew install libimobiledevice

# Ubuntu/Debian
sudo apt-get install libimobiledevice-utils

# From source
git clone https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice && ./autogen.sh && make && sudo make install
```

### Setup Port Forwarding

Forward ports from your host machine to the iOS device over USB:

```bash
# Forward JSON-RPC API port (required for automation)
iproxy 12004:12004 &

# Forward screen streaming port (required for video streaming)
iproxy 12005:12005 &
```

For a specific device (when multiple devices are connected):

```bash
# List connected devices
idevice_id -l

# Forward with specific UDID
iproxy 12004:12004 -u <DEVICE_UDID> &
iproxy 12005:12005 -u <DEVICE_UDID> &
```

### Verify Connection

```bash
# Should return {"status":"ok"} or similar
curl http://127.0.0.1:12004/health
```

### Alternative: Wi-Fi Connection

If you prefer Wi-Fi over USB (higher latency, but wireless):

1. Find your device's IP address: **Settings > Wi-Fi > (i) > IP Address**
2. Modify the server to bind to `0.0.0.0` instead of `127.0.0.1` (requires code change)
3. Connect using the device IP: `http://<DEVICE_IP>:12004/rpc`

> **Note**: USB port forwarding via `iproxy` is recommended for lower latency and more reliable connections.

---

## JSON-RPC 2.0 API

The server provides a JSON-RPC 2.0 interface with support for both HTTP and WebSocket transports.

### Server Configuration

| Setting | Default | Environment Variable |
|---------|---------|---------------------|
| Host | `127.0.0.1` | - |
| Port | `12004` | `PORT` |

### Endpoints

| Transport | Endpoint | Description |
|-----------|----------|-------------|
| HTTP POST | `POST /rpc` | Single request/response |
| WebSocket | `GET /rpc` (upgrade) | Persistent bidirectional connection |
| Health | `GET /health` | Health check endpoint |

### Available Methods

| Method | Description |
|--------|-------------|
| [`io_tap`](#io_tap) | Tap at screen coordinates |
| [`io_longpress`](#io_longpress) | Long press at screen coordinates |
| [`io_swipe`](#io_swipe) | Swipe gesture between two points |
| [`io_text`](#io_text) | Type text into focused field |
| [`io_gesture`](#io_gesture) | Complex multi-finger gestures (pinch, rotate, etc.) |
| [`dump_ui`](#dump_ui) | Capture UI accessibility hierarchy |
| [`screenshot`](#screenshot) | Capture device screenshot |
| [`apps_launch`](#apps_launch) | Launch app by bundle ID |
| [`url`](#url) | Open URL in default app |

---

## API Reference

### io_tap

Performs a tap gesture at the specified screen coordinates.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `x` | `Float` | Yes | X coordinate in screen points |
| `y` | `Float` | Yes | Y coordinate in screen points |

**curl:**
```bash
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_tap","params":{"deviceId":"","x":200,"y":400},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"io_tap","params":{"deviceId":"","x":200,"y":400},"id":1}
```

**Response:**
```json
{"jsonrpc":"2.0","result":{"success":true},"id":1}
```

---

### io_longpress

Performs a long press gesture at the specified coordinates for a given duration.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `x` | `Float` | Yes | X coordinate in screen points |
| `y` | `Float` | Yes | Y coordinate in screen points |
| `duration` | `Float` | Yes | Duration in seconds |

**curl:**
```bash
# Long press for 2 seconds
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_longpress","params":{"deviceId":"","x":200,"y":400,"duration":2.0},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"io_longpress","params":{"deviceId":"","x":200,"y":400,"duration":2.0},"id":1}
```

---

### io_swipe

Performs a swipe gesture from one point to another.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `x1` | `Int` | Yes | Starting X coordinate |
| `y1` | `Int` | Yes | Starting Y coordinate |
| `x2` | `Int` | Yes | Ending X coordinate |
| `y2` | `Int` | Yes | Ending Y coordinate |

**curl:**
```bash
# Swipe down (scroll up)
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_swipe","params":{"deviceId":"","x1":200,"y1":600,"x2":200,"y2":200},"id":1}'

# Swipe right
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_swipe","params":{"deviceId":"","x1":50,"y1":400,"x2":350,"y2":400},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"io_swipe","params":{"deviceId":"","x1":200,"y1":600,"x2":200,"y2":200},"id":1}
```

---

### io_text

Types text into the currently focused text field. Requires keyboard to be visible.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `text` | `String` | Yes | Text to type |

**curl:**
```bash
# Type text
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_text","params":{"text":"Hello, World!","deviceId":""},"id":1}'

# Type email
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"io_text","params":{"text":"user@example.com","deviceId":""},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"io_text","params":{"text":"Hello, World!","appIds":[]},"id":1}
```

---

### io_gesture

Performs complex multi-finger gestures (pinch, rotate, multi-touch). Compatible with WDA/Appium pointer actions.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `actions` | `[Action]` | Yes | Array of gesture actions |

**Action Object:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | `String` | `"press"`, `"move"`, or `"release"` |
| `x` | `Float` | X coordinate |
| `y` | `Float` | Y coordinate |
| `duration` | `Float` | Duration in seconds |
| `button` | `Int` | Finger index (0, 1, 2, ...) |

**curl - Single finger swipe:**
```bash
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"io_gesture",
    "params":{
      "deviceId":"",
      "actions":[
        {"type":"press","x":200,"y":600,"duration":0,"button":0},
        {"type":"move","x":200,"y":200,"duration":0.3,"button":0},
        {"type":"release","x":200,"y":200,"duration":0,"button":0}
      ]
    },
    "id":1
  }'
```

**curl - Two-finger pinch out (zoom in):**
```bash
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"io_gesture",
    "params":{
      "deviceId":"",
      "actions":[
        {"type":"press","x":180,"y":400,"duration":0,"button":0},
        {"type":"press","x":220,"y":400,"duration":0,"button":1},
        {"type":"move","x":100,"y":400,"duration":0.4,"button":0},
        {"type":"move","x":300,"y":400,"duration":0.4,"button":1},
        {"type":"release","x":100,"y":400,"duration":0,"button":0},
        {"type":"release","x":300,"y":400,"duration":0,"button":1}
      ]
    },
    "id":1
  }'
```

**curl - Two-finger pinch in (zoom out):**
```bash
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"io_gesture",
    "params":{
      "deviceId":"",
      "actions":[
        {"type":"press","x":100,"y":400,"duration":0,"button":0},
        {"type":"press","x":300,"y":400,"duration":0,"button":1},
        {"type":"move","x":180,"y":400,"duration":0.4,"button":0},
        {"type":"move","x":220,"y":400,"duration":0.4,"button":1},
        {"type":"release","x":180,"y":400,"duration":0,"button":0},
        {"type":"release","x":220,"y":400,"duration":0,"button":1}
      ]
    },
    "id":1
  }'
```

**WebSocket - Pinch out:**
```json
{"jsonrpc":"2.0","method":"io_gesture","params":{"deviceId":"","actions":[{"type":"press","x":180,"y":400,"duration":0,"button":0},{"type":"press","x":220,"y":400,"duration":0,"button":1},{"type":"move","x":100,"y":400,"duration":0.4,"button":0},{"type":"move","x":300,"y":400,"duration":0.4,"button":1},{"type":"release","x":100,"y":400,"duration":0,"button":0},{"type":"release","x":300,"y":400,"duration":0,"button":1}]},"id":1}
```

---

### dump_ui

Captures the complete UI accessibility hierarchy of the foreground application.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `format` | `String` | No | `"json"` (default) or `"raw"` |

**Formats:**
- `json`: Returns `ViewHierarchy` with metadata (`depth`, `axElement`)
- `raw`: Returns raw `AXElement` hierarchy directly

**curl:**
```bash
# Default JSON format
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"dump_ui","params":{"deviceId":""},"id":1}'

# Raw format
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"dump_ui","params":{"deviceId":"","format":"raw"},"id":1}'

# Pretty print with jq
curl -s -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"dump_ui","params":{"deviceId":""},"id":1}' | jq .
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"dump_ui","params":{"deviceId":"","format":"json"},"id":1}
```

**Response (JSON format):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "depth": 15,
    "axElement": {
      "identifier": "...",
      "frame": {"X": 0, "Y": 0, "Width": 390, "Height": 844},
      "label": "Accessibility Label",
      "elementType": 1,
      "enabled": true,
      "children": [...]
    }
  },
  "id": 1
}
```

---

### screenshot

Captures a screenshot of the device screen.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `format` | `String` | Yes | `"png"`, `"jpeg"`, or `"jpg"` |
| `quality` | `Int` | No | JPEG quality 1-100 (default: 50) |

**curl:**
```bash
# PNG screenshot
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"","format":"png"},"id":1}'

# JPEG with quality
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"","format":"jpeg","quality":80},"id":1}'

# Save screenshot to file
curl -s -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"","format":"png"},"id":1}' \
  | jq -r '.result.data' \
  | sed 's/data:image\/png;base64,//' \
  | base64 --decode > screenshot.png
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"","format":"png"},"id":1}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "format": "png",
    "data": "data:image/png;base64,iVBORw0KGgo..."
  },
  "id": 1
}
```

---

### apps_launch

Launches an application by its bundle identifier.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `bundleId` | `String` | Yes | App bundle identifier |

**curl:**
```bash
# Launch Safari
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"apps_launch","params":{"deviceId":"","bundleId":"com.apple.mobilesafari"},"id":1}'

# Launch Settings
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"apps_launch","params":{"deviceId":"","bundleId":"com.apple.Preferences"},"id":1}'

# Launch App Store
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"apps_launch","params":{"deviceId":"","bundleId":"com.apple.AppStore"},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"apps_launch","params":{"deviceId":"","bundleId":"com.apple.mobilesafari"},"id":1}
```

---

### url

Opens a URL using the system's default application.

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | `String` | Yes | Device identifier (can be empty) |
| `url` | `String` | Yes | URL to open |

**Supported URL schemes:**
- `http://`, `https://` - Opens in Safari
- `tel:` - Opens Phone app
- `mailto:` - Opens Mail app
- `maps:` - Opens Maps app
- Custom app URL schemes

**curl:**
```bash
# Open website
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"url","params":{"deviceId":"","url":"https://www.apple.com"},"id":1}'

# Open Maps location
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"url","params":{"deviceId":"","url":"maps://?q=San+Francisco"},"id":1}'

# Open deep link
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"url","params":{"deviceId":"","url":"myapp://action"},"id":1}'
```

**WebSocket:**
```json
{"jsonrpc":"2.0","method":"url","params":{"deviceId":"","url":"https://github.com"},"id":1}
```

---

## WebSocket Examples

WebSocket provides a persistent connection for lower latency when sending multiple commands.

### Using wscat

```bash
# Install
npm install -g wscat

# Connect
wscat -c ws://127.0.0.1:12004/rpc
```

Then send JSON-RPC requests interactively:
```json
{"jsonrpc":"2.0","method":"io_tap","params":{"x":200,"y":400},"id":1}
{"jsonrpc":"2.0","method":"dump_ui","params":{"deviceId":""},"id":2}
{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"","format":"png"},"id":3}
```

### Using websocat

```bash
# Install
brew install websocat

# Interactive session
websocat ws://127.0.0.1:12004/rpc

# One-liner
echo '{"jsonrpc":"2.0","method":"io_tap","params":{"x":200,"y":400},"id":1}' | websocat ws://127.0.0.1:12004/rpc
```

### Using Python

```python
import asyncio
import websockets
import json

async def main():
    async with websockets.connect("ws://127.0.0.1:12004/rpc") as ws:
        # Tap
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "io_tap",
            "params": {"x": 200, "y": 400},
            "id": 1
        }))
        print(await ws.recv())

        # Type text
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "io_text",
            "params": {"text": "Hello!", "appIds": []},
            "id": 2
        }))
        print(await ws.recv())

        # Dump UI
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "dump_ui",
            "params": {"deviceId": ""},
            "id": 3
        }))
        print(await ws.recv())

asyncio.run(main())
```

### Using JavaScript/Node.js

```javascript
const WebSocket = require('ws');

const ws = new WebSocket('ws://127.0.0.1:12004/rpc');

ws.on('open', () => {
    // Tap
    ws.send(JSON.stringify({
        jsonrpc: '2.0',
        method: 'io_tap',
        params: { x: 200, y: 400 },
        id: 1
    }));
});

ws.on('message', (data) => {
    const response = JSON.parse(data);
    console.log('Response:', response);

    if (response.id === 1) {
        // After tap, take screenshot
        ws.send(JSON.stringify({
            jsonrpc: '2.0',
            method: 'screenshot',
            params: { deviceId: '', format: 'png' },
            id: 2
        }));
    } else {
        ws.close();
    }
});
```

---

## JSON-RPC Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Not a valid JSON-RPC request |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal server error |
| -32000 | Timeout | Operation timed out |
| -32001 | Precondition failed | Precondition not met |

**Error Response Example:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params: Missing required field 'x'"
  },
  "id": 1
}
```

---

## Screen Streaming

### Overview

DeviceKit iOS provides real-time H.264 video streaming via TCP on port 12005. The stream is compatible with standard video players and processing pipelines.

### Quick Start: screencapture.sh (Recommended)

The easiest way to view the device screen is using the included helper script:

```bash
# From the devicekit-ios directory
./scripts/screencapture.sh --setup-iproxy
```

This script automatically:
- Installs ffmpeg via Homebrew (if not present)
- Sets up iproxy port forwarding (if `--setup-iproxy` flag is used)
- Connects to the H.264 stream and displays it with ffplay

#### Script Options

```bash
# Basic usage (requires iproxy already running or simulator)
./scripts/screencapture.sh

# Auto-setup iproxy for real devices
./scripts/screencapture.sh --setup-iproxy

# Connect to specific device by UDID
./scripts/screencapture.sh --setup-iproxy --udid 00008030-001234567890402E

# Connect over Wi-Fi (use device IP)
./scripts/screencapture.sh --host 192.168.1.100

# Record to file instead of displaying
./scripts/screencapture.sh --record output.mp4

# Low-latency mode (less buffering, may drop frames)
./scripts/screencapture.sh --low-latency

# Show all options
./scripts/screencapture.sh --help
```

### Manual Connection Options

#### Option 1: USB Port Forwarding

Use `iproxy` for low-latency, reliable streaming over USB:

```bash
# Set up port forwarding (see Port Forwarding section above)
iproxy 12005:12005 &

# Stream will be available at localhost
# Host: 127.0.0.1
# Port: 12005
```

#### Option 2: Wi-Fi Direct Connection

Connect directly over Wi-Fi (higher latency):

1. Get device IP address: **Settings > Wi-Fi > (i) > IP Address**
2. Use device IP directly in streaming commands

### Using ffplay Directly

```bash
# Via USB (with iproxy running)
nc 127.0.0.1 12005 | ffplay -fflags nobuffer -flags low_delay -f h264 -

# Via Wi-Fi
nc <DEVICE_IP> 12005 | ffplay -fflags nobuffer -flags low_delay -f h264 -
```

### GStreamer Setup (Docker)

```bash
# Pull GStreamer container
docker pull restreamio/gstreamer:2023-12-05T16-57-29Z-prod

# Run container (use --network=host for USB forwarding)
docker run -ti --network=host restreamio/gstreamer:2023-12-05T16-57-29Z-prod
```

### Recording Stream

1. Start the ScreenStreamer app on device
2. Select **BroadcastUploadExtensions > Start Broadcast**
3. Record with GStreamer:

**Via USB (iproxy):**
```bash
# Requires iproxy 12005:12005 running on host
gst-launch-1.0 tcpclientsrc -e do-timestamp=true host=127.0.0.1 port=12005 \
  ! h264parse ! h264timestamper ! identity sync=true \
  ! mp4mux ! filesink location=recording.mp4
```

**Via Wi-Fi:**
```bash
export DEVICE_IP=<your_device_ip>

gst-launch-1.0 tcpclientsrc -e do-timestamp=true host=$DEVICE_IP port=12005 \
  ! h264parse ! h264timestamper ! identity sync=true \
  ! mp4mux ! filesink location=recording.mp4
```

4. Stop recording with `Ctrl+C`
5. Copy video from container (if using Docker without --network=host):
```bash
docker cp <container_id>:/recording.mp4 ./recording.mp4
```

---

## Building

### Build App

```bash
xcodebuild \
  -workspace devicekit-ios.xcworkspace \
  -scheme devicekit-ios \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### Build Test Runner

In Xcode: **Product > Build For > Testing**

### Create IPA

1. Create `Payload` directory
2. Move `.app` artifact to `Payload/`
3. Zip and rename: `zip -r app.ipa Payload/`

---

## Resources

- [Video Compression: Keyframes](https://blog.video.ibm.com/streaming-video-tips/keyframes-interframe-video-compression/)
- [Network Abstraction Layer](https://en.wikipedia.org/wiki/Network_Abstraction_Layer)
- [H.264/AVC](https://en.wikipedia.org/wiki/Advanced_Video_Coding)
- [WWDC 2014: Direct Access to Video Encoding](https://developer.apple.com/videos/play/wwdc2014/513/)
