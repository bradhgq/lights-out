// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LightsOut",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LightsOutCore",
            path: "Sources/LightsOutCore"
        ),
        .executableTarget(
            name: "LightsOut",
            dependencies: ["LightsOutCore"],
            path: "Sources/LightsOut",
            swiftSettings: [
                .define("DEV_MODE", .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"]),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "LightsOutHelper",
            path: "Sources/LightsOutHelper"
        ),
        .executableTarget(
            name: "LightsOutTests",
            dependencies: ["LightsOutCore"],
            path: "Tests/LightsOutTests"
        ),
    ]
)
