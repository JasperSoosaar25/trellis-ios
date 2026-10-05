// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubKit",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [.library(name: "GitHubKit", targets: ["GitHubKit"])],
    targets: [
        .target(name: "GitHubKit"),
        .testTarget(name: "GitHubKitTests", dependencies: ["GitHubKit"])
    ],
    swiftLanguageModes: [.v6]
)
