// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloatDoor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FloatDoor", targets: ["FloatDoor"])
    ],
    targets: [
        .executableTarget(
            name: "FloatDoor",
            path: "Sources/FloatDoor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FloatDoorTests",
            dependencies: ["FloatDoor"],
            path: "Tests/FloatDoorTests"
        )
    ]
)
