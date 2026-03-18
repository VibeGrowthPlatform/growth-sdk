// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VibeGrowthSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "VibeGrowthSDK",
            targets: ["VibeGrowthSDK"]
        )
    ],
    targets: [
        .target(
            name: "VibeGrowthSDK",
            path: "Sources/VibeGrowthSDK"
        )
    ]
)
