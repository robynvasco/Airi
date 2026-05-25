// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AiriLocalCLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AiriLocalSpike", targets: ["AiriLocalSpike"])
    ],
    targets: [
        .executableTarget(
            name: "AiriLocalSpike",
            path: "Sources/AiriFoundationSpike"
        )
    ]
)
