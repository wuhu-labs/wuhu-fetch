// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "wuhu-fetch",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Fetch",
      targets: ["Fetch"]
    ),
    .library(
      name: "FetchURLSession",
      targets: ["FetchURLSession"]
    ),
    .library(
      name: "FetchAsyncHTTPClient",
      targets: ["FetchAsyncHTTPClient"]
    ),
    .library(
      name: "FetchSSE",
      targets: ["FetchSSE"]
    ),
    .library(
      name: "FetchTesting",
      targets: ["FetchTesting"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.4"),
    .package(url: "https://github.com/apple/swift-http-types", from: "1.5.1"),
    .package(url: "https://github.com/swift-server/async-http-client.git", exact: "1.30.3"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
  ],
  targets: [
    .target(
      name: "Fetch",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "HTTPTypes", package: "swift-http-types"),
      ]
    ),
    .target(
      name: "FetchURLSession",
      dependencies: [
        "Fetch",
      ]
    ),
    .target(
      name: "FetchAsyncHTTPClient",
      dependencies: [
        "Fetch",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
      ]
    ),
    .target(
      name: "FetchSSE",
      dependencies: [
        "Fetch",
      ]
    ),
    .target(
      name: "FetchTesting",
      dependencies: [
        "Fetch",
      ],
      resources: [
        .process("Resources/integration_server.py"),
      ]
    ),
    .testTarget(
      name: "FetchTests",
      dependencies: [
        "Fetch",
        "FetchSSE",
        "FetchTesting",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "FetchURLSessionTests",
      dependencies: [
        "FetchURLSession",
        "Fetch",
        "FetchTesting",
      ]
    ),
    .testTarget(
      name: "FetchAsyncHTTPClientTests",
      dependencies: [
        "FetchAsyncHTTPClient",
        "Fetch",
        "FetchTesting",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
      ]
    ),
  ]
)
