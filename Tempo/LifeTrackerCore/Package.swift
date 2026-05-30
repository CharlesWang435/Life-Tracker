// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LifeTrackerCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LifeTrackerCore",
            targets: ["LifeTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "LifeTrackerCore"
        )
    ]
)
