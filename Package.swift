// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AsyncMux",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "AsyncMux",
            targets: ["AsyncMux"]),
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AsyncMux",
            dependencies: [],
			path: "AsyncMux/Sources",
			swiftSettings: [
				.unsafeFlags(["~swift-strict-concurrency=complete"])
			]
        ),
    ]
)
