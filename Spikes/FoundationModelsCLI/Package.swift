// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AiriLocalCLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AiriLocalCore", targets: ["AiriLocalCore"]),
        .executable(name: "AiriLocalSpike", targets: ["AiriLocalSpike"])
    ],
    targets: [
        .target(name: "AiriLocalCore"),
        .executableTarget(
            name: "AiriLocalSpike",
            dependencies: ["AiriLocalCore"],
            path: "Sources/AiriLocalSpike"
        ),
        .testTarget(
            name: "AiriLocalCoreTests",
            dependencies: ["AiriLocalCore"]
        )
    ]
)
