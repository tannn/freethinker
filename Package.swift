// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeThinker",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "FreeThinker",
            targets: ["FreeThinker"]
        ),
        .executable(
            name: "FreeThinkerApp",
            targets: ["FreeThinkerApp"]
        )
    ],
    targets: [
        .target(
            name: "FreeThinker",
            path: "FreeThinker"
        ),
        .executableTarget(
            name: "FreeThinkerApp",
            dependencies: ["FreeThinker"],
            path: "FreeThinkerApp",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "FreeThinkerTests",
            dependencies: ["FreeThinker"],
            path: "FreeThinkerTests"
        ),
        .testTarget(
            name: "FreeThinkerPerformanceTests",
            dependencies: ["FreeThinker"],
            path: "FreeThinkerPerformanceTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "FreeThinkerUITests",
            dependencies: ["FreeThinker"],
            path: "FreeThinkerUITests"
        )
    ]
)
