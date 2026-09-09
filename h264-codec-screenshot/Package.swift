// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "H264ScreenshotCodec",
    products: [
        .library(
            name: "H264ScreenshotCodec",
            targets: ["H264ScreenshotCodec"])
    ],
    targets: [
        .target(
            name: "H264ScreenshotCodec",
            path: "Sources/h264-codec"),
        .testTarget(
            name: "H264ScreenshotCodecTests",
            dependencies: ["H264ScreenshotCodec"],
            path: "Tests/h264-codecTests")
    ]
)
