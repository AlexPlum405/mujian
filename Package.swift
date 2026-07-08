// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NovelReader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NovelReader", targets: ["NovelReaderApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "NovelReaderApp",
            dependencies: [.product(name: "SwiftSoup", package: "SwiftSoup"), "XPathBridge"]
        ),
        .target(
            name: "XPathBridge",
            path: "Sources/XPathBridge",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/libxml2"])
            ],
            linkerSettings: [.linkedLibrary("xml2")]
        ),
        .testTarget(
            name: "NovelReaderAppTests",
            dependencies: ["NovelReaderApp"]
        )
    ]
)
