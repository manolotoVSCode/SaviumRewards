// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RewardsCore",
    platforms: [.iOS("27.0"), .macOS("15.0")],
    products: [.library(name: "RewardsCore", targets: ["RewardsCore"])],
    targets: [
        .target(name: "RewardsCore"),
        .testTarget(name: "RewardsCoreTests", dependencies: ["RewardsCore"],
                    resources: [.copy("Fixtures")]),
    ]
)
