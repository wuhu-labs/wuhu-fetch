// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "wuhu-fetch",
    products: [
        .library(
            name: "WuhuFetch",
            targets: ["WuhuFetch"]
        ),
    ],
    targets: [
        .target(
            name: "WuhuFetch"
        ),
        .testTarget(
            name: "WuhuFetchTests",
            dependencies: ["WuhuFetch"]
        ),
    ]
)
