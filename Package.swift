// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Rezodoro",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Rezodoro",
            path: "Sources/Rezodoro",
            exclude: ["Info.plist"]
        )
    ]
)
