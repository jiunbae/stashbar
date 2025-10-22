// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileStackApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FileStackApp", targets: ["FileStackApp"])
    ],
    targets: [
        .executableTarget(
            name: "FileStackApp",
            path: "Sources"
        )
    ]
)
