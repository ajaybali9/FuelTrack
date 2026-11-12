// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FuelTrack",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
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
