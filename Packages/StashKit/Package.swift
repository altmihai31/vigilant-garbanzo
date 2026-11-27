// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StashKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StashKit", targets: ["StashKit"])
    ],
    targets: [
        .target(name: "StashKit"),
        .testTarget(name: "StashKitTests", dependencies: ["StashKit"])
    ]
)
