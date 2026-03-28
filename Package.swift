// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "fizze-assistant",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "fizze-assistant", targets: ["FizzeAssistant"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "FizzeAssistant",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "FizzeAssistantTests",
            dependencies: ["FizzeAssistant"]
        ),
    ]
)
