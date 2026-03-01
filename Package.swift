// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "XMLKit",
    products: [
        .library(
            name: "XMLKit",
            targets: ["XMLKit"]
        ),
    ],
    targets: [
        .target(
            name: "XMLKit"
        ),
        .testTarget(
            name: "XMLKitTests",
            dependencies: ["XMLKit"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
