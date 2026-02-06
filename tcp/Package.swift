// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TCP",
    products: [
        .library(
            name: "TCP",
            targets: ["TCP"]),
    ],
    targets: [
        .target(
            name: "TCP"),
        .testTarget(
            name: "TCPTests",
            dependencies: ["TCP"]),
    ]
)
