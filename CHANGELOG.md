## [0.0.12](https://github.com/mobile-next/devicekit-ios/releases/tag/0.0.12) (2026-04-15)
* General: Bump deployment target from iOS 14 to iOS 16 for smaller swift frameworks overhead
* General: Only package XCUITest runner in the .ipa
* Fix: Prevent outputPath override via CodingKeys, make JSONRPCResponse Encodable only
* CI: Add build provenance attestations for release artifacts
* CI: Remove unnecessary brew install for xcbeautify

## [0.0.10](https://github.com/mobile-next/devicekit-ios/releases/tag/0.0.10) (2026-04-12)
* General: Initial public release of DeviceKit iOS
* General: JSON-RPC 2.0 server over HTTP and WebSocket
* General: Health check and graceful shutdown endpoints
* General: Add MJPEG streaming endpoint tests and test infrastructure
* iOS: Tap, swipe, long press, and multi-finger gesture synthesis
* iOS: Text input via system keyboard
* iOS: Hardware button simulation (home, lock, volume)
* iOS: App launch, terminate, and foreground detection
* iOS: Full accessibility tree inspection (UI hierarchy dump)
* iOS: Screenshot capture (PNG/JPEG with configurable quality)
* iOS: Real-time MJPEG screen streaming with configurable fps, quality, and scale
* iOS: Real-time H264 screen streaming with configurable fps, bitrate, quality, and scale
* iOS: ReplayKit broadcast extension with H264 video and Opus audio
* iOS: Device orientation get/set
* iOS: URL opening
* iOS: Device info (screen size, scale)
