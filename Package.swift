// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PluginHub",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PluginHub", targets: ["PluginHubApp"]),
        .library(name: "PluginHubCore", targets: ["PluginHubCore"]),
        .executable(name: "PluginHubWidget", targets: ["PluginHubWidget"])
    ],
    targets: [
        .target(
            name: "PluginHubCore"
        ),
        .executableTarget(
            name: "PluginHubApp",
            dependencies: ["PluginHubCore"]
        ),
        .executableTarget(
            name: "PluginHubWidget",
            dependencies: ["PluginHubCore"],
            path: "Sources/PluginHubWidget"
        ),
        .testTarget(
            name: "PluginHubCoreTests",
            dependencies: ["PluginHubCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
