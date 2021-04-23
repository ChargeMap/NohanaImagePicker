// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NohanaImagePicker",
    products: [
        .library(
            name: "NohanaImagePicker",
            targets: ["NohanaImagePicker"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NohanaImagePicker",
            dependencies: []),
    ]
)
