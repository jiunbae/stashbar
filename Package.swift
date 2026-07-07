// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileStackApp",
    defaultLocalization: "ko",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FileStackCore", targets: ["FileStackCore"]),
        .executable(name: "FileStackApp", targets: ["FileStackApp"])
    ],
    targets: [
        .target(
            name: "FileStackCore",
            path: "Sources/FileStackCore"
        ),
        .executableTarget(
            name: "FileStackApp",
            dependencies: ["FileStackCore"],
            path: "Sources/FileStackApp",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "FileStackAppTests",
            dependencies: ["FileStackCore"],
            path: "Tests/FileStackAppTests"
        )
    ]
)
