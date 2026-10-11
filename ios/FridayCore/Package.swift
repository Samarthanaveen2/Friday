// swift-tools-version: 6.0
import PackageDescription

// Pure logic for Friday (no UIKit/SwiftUI). Runs with `swift test` on Linux and in CI.
let package = Package(
    name: "FridayCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "FridayCore", targets: ["FridayCore"])],
    targets: [
        .target(name: "FridayCore"),
        // Runs the dictation evals through the app's exact cleanup path against real Groq.
        .executableTarget(name: "FridayEval", dependencies: ["FridayCore"]),
        .testTarget(name: "FridayCoreTests", dependencies: ["FridayCore"]),
    ]
)
