// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "NSLocalizedStringLinter",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .executable(
      name: "nslocalizedstring-linter",
      targets: ["nslocalizedstring-linter"]
    )
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/swiftlang/swift-syntax.git", branch: "main")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "nslocalizedstring-linter",
      dependencies: [
        .byName(name: "NSLocalizedStringLinter")
      ]
    ),
    .target(
      name: "NSLocalizedStringLinter",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "NSLocalizedStringLinterTests",
      dependencies: ["NSLocalizedStringLinter"],
      resources: [
        .copy("Fixtures")
      ]
    ),
  ]
)
