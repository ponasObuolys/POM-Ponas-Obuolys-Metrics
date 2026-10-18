// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "POM",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
        .package(path: "Packages/POMUsageKit")
    ],
    targets: [
        .target(
            name: "POMCore",
            dependencies: [.product(name: "POMUsageKit", package: "POMUsageKit")],
            path: "Sources/POMCore"
        ),
        .executableTarget(
            name: "POM",
            dependencies: ["POMCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/POM",
            resources: [.process("Resources")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(
            name: "pom-tests",
            dependencies: ["POMCore"],
            path: "tests/POMCoreTests"
        ),
    ]
)
