// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "POMCompanion",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "POMCompanionUI", targets: ["POMCompanionUI"])],
    dependencies: [.package(path: "../../Packages/POMUsageKit")],
    targets: [
        .target(name: "POMCompanionData", dependencies: [.product(name: "POMUsageKit", package: "POMUsageKit")]),
        .target(name: "POMCompanionUI", dependencies: ["POMCompanionData"], resources: [.process("Resources")]),
        .executableTarget(name: "pom-companion-preview", dependencies: ["POMCompanionUI"], path: "App", exclude: ["Assets.xcassets", "Info.plist", "Mac.entitlements", "PrivacyInfo.xcprivacy"]),
        .executableTarget(name: "pom-companion-checks", dependencies: ["POMCompanionData"], path: "Tests/Data"),
        .executableTarget(name: "pom-companion-visual-checks", dependencies: ["POMCompanionUI"], path: "Tests/Visual")
    ]
)
