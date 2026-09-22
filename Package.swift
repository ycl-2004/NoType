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
                "LlamaFramework",
            ],
            path: "Sources/Typeless"
        ),
        .binaryTarget(
            name: "LlamaFramework",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11102/llama-b11102-xcframework.zip",
            checksum: "00fa4137b5e8e5821ec9a01ab1e7c2bd6cc7329637b5308369ce64437f9693b7"
        ),
        .testTarget(
            name: "TypelessTests",
            dependencies: ["Typeless"],
            path: "Tests/TypelessTests"
        ),
    ]
)
