// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Raindrops",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Raindrops",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)