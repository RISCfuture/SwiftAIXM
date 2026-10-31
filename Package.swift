// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("ImmutableWeakCaptures"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .strictMemorySafety()
]

let package = Package(
  name: "SwiftAIXM",
  defaultLocalization: "en",
  platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26), .tvOS(.v26), .visionOS(.v26)],
  products: [
    .library(
      name: "SwiftAIXM",
      targets: ["SwiftAIXM"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.5.0")
  ],
  targets: [
    .target(
      name: "SwiftAIXM",
      resources: [.process("Resources")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "SwiftAIXMTests",
      dependencies: ["SwiftAIXM"],
      resources: [.copy("Fixtures")],
      swiftSettings: swiftSettings
    ),
    .executableTarget(
      name: "SwiftAIXM_E2E",
      dependencies: [
        "SwiftAIXM",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      swiftSettings: swiftSettings
    )
  ],
  swiftLanguageModes: [.v5, .v6]
)
