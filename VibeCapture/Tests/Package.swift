// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VibeCaptureTests",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "VibeCaptureTestHelpers", targets: ["VibeCaptureTestHelpers"])
    ],
    dependencies: [],
    targets: [
        // Test helper library containing mocks
        .target(
            name: "VibeCaptureTestHelpers",
            dependencies: [],
            path: "VibeCaptureTests/Mocks"
        ),
        // Note: Full unit tests require Xcode test target integration
        // as they depend on @testable import VibeCap
    ]
)
