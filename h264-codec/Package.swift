// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "H264Codec",
    products: [
        .library(
            name: "H264Codec",
            targets: ["H264Codec"])
    ],
    targets: [
        .target(
            name: "H264Codec"),
        .testTarget(
            name: "H264CodecTests",
            dependencies: ["H264Codec"])
    ]
)
