// swift-tools-version: 5.9
import PackageDescription

// LightsOutCore is platform-neutral Swift and targets both macOS (for the main app)
// and iOS (for the companion app in ios/). The app + helper executable targets here
// stay macOS-only; the iOS app is built via Xcode and links LightsOutCore as a local
// package reference (see ios/LightsOutiOS.xcodeproj).
let package = Package(
    name: "LightsOut",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LightsOutCore", targets: ["LightsOutCore"]),
    ],
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
        .testTarget(
            name: "LightsOutTests",
            dependencies: ["LightsOutCore"],
            path: "Tests/LightsOutTests"
        ),
    ]
)
