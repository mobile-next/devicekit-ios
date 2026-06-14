# DeviceKit iOS

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016.0+-blue.svg?style=flat-square)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-FSL--1.1--Apache--2.0-lightgrey.svg?style=flat-square)](LICENSE)

Control any iOS device or simulator over a simple JSON-RPC API. Tap, swipe, stream video, inspect the UI, from any language, over localhost.

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
- [Testing](#testing)
- [Communication](#communication)
- [License](#license)

## What You Can Build

- **Interactive automation** — Tap, swipe, long-press, type text, press hardware buttons (home, lock, volume)
- **App control** — Launch, terminate, and detect the foreground app by bundle ID
- **Live screen visibility** — MJPEG and H264 streaming at configurable FPS, bitrate, and quality
- **UI inspection** — Full accessibility tree dumps for element targeting
- **Screenshots** — PNG or JPEG capture with configurable quality
- **System control** — Get/set orientation, open URLs, query screen size and scale
- **Broadcast audio/video** — ReplayKit extension with H264 video and Opus audio over TCP
- **Flexible transport** — JSON-RPC 2.0 over WebSocket or HTTP, from any language

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 16.0           |
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

## Quick Start

Once the server is running at `127.0.0.1:12004`, make your first call:

```bash
curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"device.screenshot","params":{},"id":1}'
```

Returns a base64-encoded PNG of the current screen.

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

The ReplayKit broadcast extension provides system-level screen and audio capture over raw TCP, independent of the JSON-RPC server. These are **not** HTTP endpoints — connect with `nc` or any raw TCP client.

| Port  | Stream      | Format |
|-------|-------------|--------|
| 12005 | H264 video  | Raw NAL units |
| 12006 | Opus audio  | Length-prefixed frames (4-byte big-endian uint32) |

```bash
ios tunnel start --userspace &
ios forward 12005 12005 &

nc localhost 12005 | ffplay \
  -fflags nobuffer \
  -flags low_delay \
  -probesize 32 \
  -analyzeduration 0 \
  -framedrop \
  -sync ext \
  -f h264 -
```

## Testing

Tests run against a live XCUITest server on a booted simulator. You need one simulator running — the test harness picks the first booted device automatically.

```bash
# Install test dependencies (one-time)
cd tests && npm install && cd ..

# Run tests with code coverage
make test-coverage

# View coverage report as HTML
make coverage-html
```

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

Questions, issues, or ideas? [Open an issue](https://github.com/mobile-next/devicekit-ios/issues) — all feedback is welcome.

Want to contribute? PRs are appreciated. Check open issues for good first tasks.

## License

DeviceKit iOS is released under the [Functional Source License 1.1, Apache 2.0 Future License](LICENSE).
