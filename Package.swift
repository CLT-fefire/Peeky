// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Peeky",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PeekyCore", targets: ["PeekyCore"]),
        .executable(name: "Peeky", targets: ["Peeky"]),
        .executable(name: "PeekyQuickLook", targets: ["PeekyQuickLook"]),
    ],
    targets: [
        .target(
            name: "PeekyCore",
            path: "Sources/PeekyCore"
        ),
        .executableTarget(
            name: "Peeky",
            dependencies: ["PeekyCore"],
            path: "Sources/Peeky"
        ),
        .executableTarget(
            name: "PeekyQuickLook",
            dependencies: ["PeekyCore"],
            path: "Sources/PeekyQuickLook"
        ),
        .testTarget(
            name: "PeekyCoreTests",
            dependencies: ["PeekyCore"],
            path: "Tests/PeekyCoreTests"
        ),
    ]
)
