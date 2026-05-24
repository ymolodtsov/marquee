// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MarqueeTextEdit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "MarqueeTextEdit",
            targets: ["MarqueeTextEditApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MarqueeTextEditApp",
            path: "Sources/MarqueeTextEditApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
