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
      name: "FetchTesting",
      targets: ["FetchTesting"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.4"),
    .package(url: "https://github.com/apple/swift-http-types", from: "1.5.1"),
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
        "FetchTesting",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
  ]
)
