// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rezodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Rezodoro",
            path: "Sources/Rezodoro",
            exclude: ["Info.plist", "Resources/AppIcon-source.png", "Resources/AppIcon.icns"],
            resources: [
                .copy("Resources/MenuBarIcon.png")
            ]
        )
    ]
)
