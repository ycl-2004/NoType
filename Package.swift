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
        .package(url: "https://github.com/k2-fsa/sherpa-onnx.git", exact: "1.13.7"),
    ],
    targets: [
        .executableTarget(
            name: "Typeless",
            dependencies: [
                .product(name: "sherpa-onnx", package: "sherpa-onnx"),
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
