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
    dependencies: [
        .package(url: "https://github.com/lemire/SwiftBitset.git",  from: "0.3.2")
    ],
    targets: [
        .target(
            name: "CompilerKit",
            dependencies: ["Bitset"]),
        .testTarget(
            name: "CompilerKitTests",
            dependencies: ["CompilerKit"]),
    ]
)
