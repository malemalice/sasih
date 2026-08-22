// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Blackout",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "BlackoutCore",
            path: "Sources/BlackoutCore"
        ),
        .executableTarget(
            name: "BlackoutSpike",
            path: "Sources/BlackoutSpike"
        ),
        .executableTarget(
            name: "BlackoutApp",
            dependencies: ["BlackoutCore"],
            path: "Sources/BlackoutApp",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "BlackoutCoreTests",
            dependencies: ["BlackoutCore"],
            path: "Tests/BlackoutCoreTests"
        ),
    ]
)
