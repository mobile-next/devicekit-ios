# DeviceKit iOS

DeviceKit iOS is a screen streaming and UI automation framework for iOS devices. It provides:
- **Screen Streaming**: Real-time H.264 video streaming over TCP (port 12005)
- **UI Automation**: HTTP API for programmatic device control (port 12004)

---

## JSON-RPC 2.0 API (Recommended)

The server provides a JSON-RPC 2.0 interface on `127.0.0.1:12004` with support for both HTTP and WebSocket transports.

### Server Configuration

| Setting | Default | Environment Variable |
|---------|---------|---------------------|
| Host | `127.0.0.1` | - |
| Port | `12004` | `PORT` |
| Timeout | `100s` | - |

### Endpoints

| Transport | Endpoint | Description |
|-----------|----------|-------------|
| HTTP POST | `POST /rpc` | Single request/response |
| WebSocket | `GET /rpc` | Persistent bidirectional connection |
| HTTP GET | `GET /health` | Health check |

### Available Methods

| Method | Description |
|--------|-------------|
| `tap` | Perform tap or long-press gesture |
| `dumpUI` | Capture UI view hierarchy |

---

### HTTP POST Examples (curl)

#### Tap

```bash
# Simple tap at coordinates (100, 200)
curl -X POST http://127.0.0.1:12004/rpc \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tap",
        "params": {"x": 100.0, "y": 200.0},
        "id": 1
    }'

# Response:
# {"jsonrpc":"2.0","result":{"success":true},"id":1}
```

```bash
# Long-press for 2 seconds
curl -X POST http://127.0.0.1:12004/rpc \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tap",
        "params": {"x": 150.0, "y": 300.0, "duration": 2.0},
        "id": 2
    }'
```

#### DumpUI

```bash
# Capture UI hierarchy
curl -X POST http://127.0.0.1:12004/rpc \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "dumpUI",
        "params": {"appIds": [], "excludeKeyboardElements": false},
        "id": 3
    }'

# Response:
# {"jsonrpc":"2.0","result":{"axElement":{...},"depth":15},"id":3}
```

```bash
# Capture UI hierarchy excluding keyboard, pretty-printed
curl -X POST http://127.0.0.1:12004/rpc \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "dumpUI",
        "params": {"appIds": [], "excludeKeyboardElements": true},
        "id": 4
    }' | jq .
```

---

### WebSocket Examples

WebSocket provides a persistent connection for lower latency when sending multiple commands.

#### Using websocat

Install [websocat](https://github.com/vi/websocat):
```bash
# macOS
brew install websocat

# or cargo
cargo install websocat
```

Interactive session:
```bash
websocat ws://127.0.0.1:12004/rpc
```

Then type JSON-RPC requests:
```json
{"jsonrpc": "2.0", "method": "tap", "params": {"x": 100, "y": 200}, "id": 1}
{"jsonrpc": "2.0", "method": "dumpUI", "params": {"appIds": [], "excludeKeyboardElements": false}, "id": 2}
```

One-liner with websocat:
```bash
echo '{"jsonrpc": "2.0", "method": "tap", "params": {"x": 100, "y": 200}, "id": 1}' | websocat ws://127.0.0.1:12004/rpc
```

#### Using wscat

Install [wscat](https://github.com/websockets/wscat):
```bash
npm install -g wscat
```

Interactive session:
```bash
wscat -c ws://127.0.0.1:12004/rpc
```

#### Using Python

```python
import asyncio
import websockets
import json

async def main():
    async with websockets.connect("ws://127.0.0.1:12004/rpc") as ws:
        # Tap
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "tap",
            "params": {"x": 100, "y": 200},
            "id": 1
        }))
        response = await ws.recv()
        print(f"Tap response: {response}")

        # DumpUI
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "dumpUI",
            "params": {"appIds": [], "excludeKeyboardElements": False},
            "id": 2
        }))
        response = await ws.recv()
        print(f"DumpUI response: {response}")

asyncio.run(main())
```

#### Using JavaScript/Node.js

```javascript
const WebSocket = require('ws');

const ws = new WebSocket('ws://127.0.0.1:12004/rpc');

ws.on('open', () => {
    // Tap
    ws.send(JSON.stringify({
        jsonrpc: '2.0',
        method: 'tap',
        params: { x: 100, y: 200 },
        id: 1
    }));
});

ws.on('message', (data) => {
    const response = JSON.parse(data);
    console.log('Response:', response);

    if (response.id === 1) {
        // After tap, request UI dump
        ws.send(JSON.stringify({
            jsonrpc: '2.0',
            method: 'dumpUI',
            params: { appIds: [], excludeKeyboardElements: false },
            id: 2
        }));
    } else {
        ws.close();
    }
});
```

---

### JSON-RPC Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Not a valid JSON-RPC request |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal server error |
| -32000 | Timeout | Operation timed out |
| -32001 | Precondition failed | Invalid request (e.g., bad coordinates) |

Error response example:
```json
{
    "jsonrpc": "2.0",
    "error": {
        "code": -32601,
        "message": "Method not found"
    },
    "id": 1
}
```

---

## Legacy HTTP REST API

> **Note:** The JSON-RPC API above is recommended. The REST API below is kept for backward compatibility.

### Available Endpoints

#### POST `/tap`

Performs a tap or long-press gesture at the specified screen coordinates.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `x` | `Float` | Yes | X coordinate in screen points |
| `y` | `Float` | Yes | Y coordinate in screen points |
| `duration` | `Float` | No | Duration in seconds for long-press (omit for tap) |

**Response:**
- `200 OK` - Tap performed successfully
- `400 Bad Request` - Invalid request body
- `500 Internal Server Error` - Tap synthesis failed

**curl Examples:**

```bash
# Simple tap at coordinates (100, 200)
curl -X POST http://127.0.0.1:12004/tap \
    -H "Content-Type: application/json" \
    -d '{"x": 100.0, "y": 200.0}'

# Long-press for 2 seconds at coordinates (150, 300)
curl -X POST http://127.0.0.1:12004/tap \
    -H "Content-Type: application/json" \
    -d '{"x": 150.0, "y": 300.0, "duration": 2.0}'

# Tap with explicit null duration (same as simple tap)
curl -X POST http://127.0.0.1:12004/tap \
    -H "Content-Type: application/json" \
    -d '{"x": 200.0, "y": 400.0, "duration": null}'
```

---

#### POST `/dumpUI`

Captures the complete view hierarchy of the foreground application.

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `appIds` | `[String]` | Yes | Array of bundle IDs (can be empty) |
| `excludeKeyboardElements` | `Bool` | Yes | Filter out keyboard UI elements |

**Response:**
- `200 OK` - Returns JSON with view hierarchy
- `400 Bad Request` - Invalid request body
- `408 Request Timeout` - Snapshot operation timed out
- `500 Internal Server Error` - Snapshot failure

**Response Body:**

```json
{
  "axElement": {
    "identifier": "element_id",
    "frame": {"X": 0, "Y": 0, "Width": 390, "Height": 844},
    "label": "Accessibility Label",
    "elementType": 1,
    "enabled": true,
    "selected": false,
    "hasFocus": false,
    "value": "optional value",
    "title": "optional title",
    "placeholderValue": "optional placeholder",
    "horizontalSizeClass": 2,
    "verticalSizeClass": 2,
    "windowContextID": 12345.0,
    "displayID": 0,
    "children": []
  },
  "depth": 15
}
```

**curl Examples:**

```bash
# Dump UI hierarchy for all foreground apps
curl -X POST http://127.0.0.1:12004/dumpUI \
    -H "Content-Type: application/json" \
    -d '{"appIds": [], "excludeKeyboardElements": false}'

# Dump UI hierarchy excluding keyboard elements
curl -X POST http://127.0.0.1:12004/dumpUI \
    -H "Content-Type: application/json" \
    -d '{"appIds": [], "excludeKeyboardElements": true}'

# Dump UI with pretty-printed JSON output
curl -X POST http://127.0.0.1:12004/dumpUI \
    -H "Content-Type: application/json" \
    -d '{"appIds": [], "excludeKeyboardElements": false}' | jq .

# Save UI dump to file
curl -X POST http://127.0.0.1:12004/dumpUI \
    -H "Content-Type: application/json" \
    -d '{"appIds": [], "excludeKeyboardElements": false}' \
    -o ui_hierarchy.json
```

---

### Error Response Format

All error responses follow this JSON structure:

```json
{
  "code": "precondition|internal|timeout",
  "errorMessage": "Human-readable error description"
}
```

| Error Code | HTTP Status | Description |
|------------|-------------|-------------|
| `precondition` | 400 | Invalid request body or parameters |
| `timeout` | 408 | Operation timed out |
| `internal` | 500 | Internal server error |

---

## Screen Streaming

### TCP Swift Package

Basic TCP server and client utilizing Apple's [Network](https://developer.apple.com/documentation/network) framework. The server runs on the real device on port 12005 by default and expects incoming connections.

### H.264 Codec Swift Package

[VideoToolbox](https://developer.apple.com/documentation/videotoolbox) is a core framework used for hardware-accelerated H.264 video compression and decompression.

### DeviceKit iOS App

A sample app with a ReplayKit Broadcast Upload Extension for screen capture. 

### Local dev testing

#### Gstreamer setup with Docker:

- Pull this [container](https://hub.docker.com/layers/restreamio/gstreamer/2023-12-05T16-57-29Z-prod/images/sha256-be449bc2d2673b68afa9a0d35769ce7a96c2d33fd05229d4af03805cdf96f680?context=explore) with gstreamer 1.26.x version

```
docker pull restreamio/gstreamer:2023-12-05T16-57-29Z-prod
```

- Run the container 
```
docker run -ti 375dff539ee9e4b01aef020049cdaeac3b2213b59e118405be645586db408ebd
```

#### Device streaming service setup:

- Check the ip address on the device:
```
Settings -> WiFi -> Tap on "Info" icon -> copy valu from IP Address cell
```

- Run the ScreenStreamerServer App on the real iOS device

- In the opened app on the device:
```
Select "BroadcastUploadExtensions" -> Press "Start Broadcast"
```

#### Run:

- Run the gstreamer pipeline in the running docker container to record the video in mp4 file:
```
export DEVICE_IP_ADDRESS=your_device_ip_address

gst-launch-1.0 tcpclientsrc -e do-timestamp=true host=$DEVICE_IP_ADDRESS port=12005 ! h264parse ! h264timestamper ! identity sync=true ! mp4mux ! filesink location=sintel_video.mp4
```

- Stop the gstreamer recording (ctrl + C)

#### Copy the video to Host

```
docker cp container_id:/sintel_video.mp4 sintel_video.mp4
```

#### Building `app`:
```
xcodebuild \
  -workspace devicekit-ios.xcworkspace \
  -scheme devicekit-ios \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

#### Building `runner`:
```
Xcode -> Product -> Build For -> Testing
```

#### Building `ipa`:
- create a dir `Payload`
- move `.app` artifact to `Payload` dir
- zip the `Payload` dir and rename `zip` extension to `ipa`

### Useful links
- https://blog.video.ibm.com/streaming-video-tips/keyframes-interframe-video-compression/
- https://en.wikipedia.org/wiki/Network_Abstraction_Layer
- https://en.wikipedia.org/wiki/Advanced_Video_Coding
- https://developer.apple.com/videos/play/wwdc2014/513/
