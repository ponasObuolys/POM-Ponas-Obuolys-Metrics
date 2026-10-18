// swift-tools-version:5.9
import PackageDescription

// Data only: no CLI, Keychain, AppKit, Sparkle or network dependencies.
let package = Package(
    name: "POMUsageKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "POMUsageKit", targets: ["POMUsageKit"])],
    targets: [.target(name: "POMUsageKit")]
)
