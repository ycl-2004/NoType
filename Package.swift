// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "noType",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "noType", targets: ["Typeless"]),
    ],
    dependencies: [
        .package(path: "Vendor/WhisperKit-main"),
    ],
    targets: [
        .executableTarget(
            name: "Typeless",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit-main"),
            ],
            path: "Sources/Typeless"
        ),
        .testTarget(
            name: "TypelessTests",
            dependencies: ["Typeless"],
            path: "Tests/TypelessTests"
        ),
    ]
)
