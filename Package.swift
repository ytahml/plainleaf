// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Plainleaf",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Plainleaf", targets: ["Plainleaf"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
        .package(path: "Vendor/HighlighterSwift")
    ],
    targets: [
        .executableTarget(
            name: "Plainleaf",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Highlighter", package: "HighlighterSwift")
            ],
            path: "Sources/Plainleaf",
            exclude: ["Resources"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PlainleafTests",
            dependencies: ["Plainleaf"],
            path: "Tests/PlainleafTests"
        )
    ]
)
