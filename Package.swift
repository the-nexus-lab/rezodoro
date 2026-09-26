// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rezodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Rezodoro",
            path: "Sources/Rezodoro",
            // Bundle files, copied into the .app by build.sh rather than
            // shipped as a SwiftPM resource bundle (whose generated lookup
            // only works from this machine's .build directory).
            exclude: ["Info.plist", "Rezodoro.entitlements", "Resources"]
        )
    ]
)
