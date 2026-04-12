# DeviceKit iOS

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014.0+-blue.svg?style=flat-square)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg?style=flat-square)](LICENSE)

DeviceKit iOS is a JSON-RPC server for programmatic iOS device automation. It runs as an XCUITest runner, providing remote control over touch input, app management, UI inspection, screenshots, and real-time screen streaming.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Starting the Server](#starting-the-server)
  - [JSON-RPC API](#json-rpc-api)
  - [Streaming Endpoints](#streaming-endpoints)
- [Architecture](#architecture)
- [Building](#building)
- [Communication](#communication)
- [License](#license)

## Features

- [x] JSON-RPC 2.0 over WebSocket and HTTP
- [x] Tap, swipe, long press, and multi-finger gesture synthesis
- [x] Text input via system keyboard
- [x] Hardware button simulation (home, lock, volume)
- [x] App launch, terminate, and foreground detection
- [x] Full accessibility tree inspection (UI hierarchy dump)
- [x] Screenshot capture (PNG/JPEG with configurable quality)
- [x] Real-time MJPEG screen streaming
- [x] Real-time H264 screen streaming
- [x] ReplayKit broadcast extension with H264 video and Opus audio
- [x] Device orientation get/set
- [x] URL opening
- [x] Device info (screen size, scale)

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 14.0           |
| Swift    | 5.9            |
| Xcode    | 15.0+          |

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/mobile-next/devicekit-ios.git
cd devicekit-ios

# Build unsigned IPA for real devices
make ipa-unsigned

# Build XCUITest runner for simulators
make sim-zip
```

### Build Targets

| Target | Output | Description |
|--------|--------|-------------|
| `make ipa-unsigned` | `build/export/devicekit-ios-unsigned.ipa` | Unsigned IPA for arm64 devices |
| `make sim-zip-arm64` | `build/export/devicekit-ios-Sim-arm64.zip` | Simulator runner (Apple Silicon) |
| `make sim-zip-x86_64` | `build/export/devicekit-ios-Sim-x86_64.zip` | Simulator runner (Intel) |
| `make sim-zip` | Both simulator zips | arm64 + x86_64 |
| `make lint` | — | Run SwiftLint |
| `make clean` | — | Remove build artifacts |

## Usage

### Starting the Server

DeviceKit runs as an XCUITest. Once installed and launched on a device or simulator, it starts a server on `127.0.0.1:12004`.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICEKIT_LISTEN_PORT` | `12004` | JSON-RPC server port |
| `DEVICEKIT_LISTEN_HOST` | `127.0.0.1` | Bind address for the JSON-RPC server. All TCP servers (video, audio) also bind to `127.0.0.1` by default. |

**Endpoints:**

| Endpoint | Protocol | Description |
|----------|----------|-------------|
| `GET /ws` | WebSocket | JSON-RPC 2.0 |
| `POST /rpc` | HTTP | JSON-RPC 2.0 |
| `GET /health` | HTTP | Health check |
| `GET /mjpeg` | HTTP | MJPEG screen stream |
| `GET /h264` | HTTP | H264 screen stream |

### JSON-RPC API

All methods follow the [JSON-RPC 2.0](https://www.jsonrpc.org/specification) specification.

```json
{
  "jsonrpc": "2.0",
  "method": "device.io.tap",
  "params": { "x": 100, "y": 200, "deviceId": "any" },
  "id": 1
}
```

#### Input

| Method | Description |
|--------|-------------|
| `device.io.tap` | Tap at (x, y) coordinates |
| `device.io.swipe` | Swipe from (x1, y1) to (x2, y2) |
| `device.io.longpress` | Long press at (x, y) for a duration |
| `device.io.gesture` | Multi-finger gesture with press/move/release actions |
| `device.io.text` | Type text into the focused field |
| `device.io.button` | Press a hardware button (`home`, `lock`, `volumeUp`, `volumeDown`) |

#### Device

| Method | Description |
|--------|-------------|
| `device.info` | Get screen size and scale factor |
| `device.io.orientation.get` | Get current orientation (`PORTRAIT` / `LANDSCAPE`) |
| `device.io.orientation.set` | Set orientation to `PORTRAIT` or `LANDSCAPE` |
| `device.url` | Open a URL |

#### Apps

| Method | Description |
|--------|-------------|
| `device.apps.launch` | Launch an app by bundle ID |
| `device.apps.terminate` | Terminate an app by bundle ID |
| `device.apps.foreground` | Get the foreground app's bundle ID, name, and PID |

#### Inspection

| Method | Description |
|--------|-------------|
| `device.dump.ui` | Return the full accessibility view hierarchy |
| `device.screenshot` | Capture a screenshot (base64 PNG/JPEG) |

### Streaming Endpoints

#### MJPEG

```
GET /mjpeg?fps=10&quality=25&scale=100
```

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `fps` | 10 | 1–60 | Frames per second |
| `quality` | 25 | 1–100 | JPEG quality (%) |
| `scale` | 100 | 10–100 | Scale factor (%) |

#### H264

```
GET /h264?fps=30&bitrate=4000000&quality=60&scale=50
```

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `fps` | 30 | 1–60 | Frames per second |
| `bitrate` | 4000000 | 100000–10000000 | Target bitrate (bps) |
| `quality` | 60 | 1–100 | Encoder quality (%) |
| `scale` | 50 | 10–100 | Scale factor (%) |

### Broadcast Extension

The ReplayKit broadcast extension provides system-level screen and audio capture over TCP, independent of the JSON-RPC server.

| Port | Stream |
|------|--------|
| 12005 | H264 video |
| 12006 | Opus audio |

## Architecture

```
devicekit-ios/
  DeviceKit/                    # Host app (SwiftUI, triggers broadcast picker)
  DeviceKitTests/               # XCUITest runner (automation server)
    JSONRPC/                    #   JSON-RPC protocol + 15 method handlers
    Streamer/                   #   MJPEG and H264 HTTP streaming
    XCTest/                     #   Private API wrappers (touch synthesis, accessibility)
    H264Stream/                 #   Screenshot-based H264 streaming
  BroadcastUploadExtension/     # ReplayKit extension (H264 + Opus over TCP)
  h264-codec/                   # Swift package: H264 encoder (VideoToolbox)
  opus-codec/                   # Swift package: Opus encoder (wraps libopus)
```

## Dependencies

- [FlyingFox](https://github.com/swhitty/FlyingFox) — Lightweight HTTP and WebSocket server
- [libopus](https://opus-codec.org/) — Audio codec (vendored as C source in `opus-codec/`)

## Communication

- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## License

DeviceKit iOS is released under the Apache 2.0 License. See [LICENSE](LICENSE) for details.
