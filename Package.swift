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
    targets: [
        .executableTarget(
            name: "Typeless",
            dependencies: [
                "LlamaFramework",
            ],
            path: "Sources/Typeless",
            // llama.framework ships beside the executable, in .build and in the app bundle's
            // Contents/MacOS. SwiftPM adds no rpath for a binary framework on its own; without
            // this the app aborts at launch with "Library not loaded: @rpath/llama.framework".
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"]),
            ]
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
