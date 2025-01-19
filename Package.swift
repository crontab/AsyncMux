// swift-tools-version: 6.0

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
            path: "AsyncMux/Sources"
        ),
    ],
	swiftLanguageVersions: [.version("6")]
)
