// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Inputalk",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Inputalk",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            resources: [
                .copy("Resources/MenuBarIcon.png"),
                .copy("Resources/MenuBarIcon@2x.png"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        )
    ]
)
