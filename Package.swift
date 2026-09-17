// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "xcode-mcp-docs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "xcode-mcp-docs",
            targets: ["XcodeMCPDocsCLI"]
        ),
        .library(
            name: "XcodeMCPDocsKit",
            targets: ["XcodeMCPDocsKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "XcodeMCPDocsCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "XcodeMCPDocsKit",
            ]
        ),
        .target(
            name: "XcodeMCPDocsKit"
        ),
        .testTarget(
            name: "XcodeMCPDocsKitTests",
            dependencies: ["XcodeMCPDocsKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
