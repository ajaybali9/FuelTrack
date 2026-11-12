// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FuelTrack",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FuelTrack",
            targets: ["FuelTrack"]
        ),
    ],
    targets: [
        .target(
            name: "FuelTrack"
        ),
    ]
)
