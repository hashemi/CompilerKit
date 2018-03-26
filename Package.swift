// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CompilerKit",
    products: [
        .library(
            name: "CompilerKit",
            targets: ["CompilerKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CompilerKit",
            dependencies: []),
        .testTarget(
            name: "CompilerKitTests",
            dependencies: ["CompilerKit"]),
    ]
)
