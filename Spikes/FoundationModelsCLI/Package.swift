// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FoundationModelsCLI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "AiriFoundationSpike", targets: ["AiriFoundationSpike"])
    ],
    targets: [
        .executableTarget(
            name: "AiriFoundationSpike"
        )
    ]
)

