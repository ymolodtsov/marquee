// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarqueeTextEdit",
    platforms: [
        .macOS(.v13)
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
            path: "Sources/MarqueeTextEditApp"
        )
    ]
)
