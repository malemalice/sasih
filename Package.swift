// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sasih",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SasihCore",
            path: "Sources/SasihCore"
        ),
        .executableTarget(
            name: "SasihSpike",
            path: "Sources/SasihSpike"
        ),
        .executableTarget(
            name: "SasihApp",
            dependencies: ["SasihCore"],
            path: "Sources/SasihApp",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "SasihCoreTests",
            dependencies: ["SasihCore"],
            path: "Tests/SasihCoreTests"
        ),
    ]
)
