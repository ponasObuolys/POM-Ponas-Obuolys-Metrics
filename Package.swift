// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "POM",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "POMCore",
            path: "Sources/POMCore"
        ),
        .executableTarget(
            name: "POM",
            dependencies: ["POMCore"],
            path: "Sources/POM"
        ),
        .executableTarget(
            name: "pom-tests",
            dependencies: ["POMCore"],
            path: "tests/POMCoreTests"
        ),
    ]
)
