// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrantBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GrantBar",
            path: "Sources/GrantBar"
        )
    ]
)
