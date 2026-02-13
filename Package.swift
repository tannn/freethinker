// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeThinker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FreeThinker",
            targets: ["FreeThinker"]
        )
    ],
    targets: [
        .target(
            name: "FreeThinker",
            path: "FreeThinker"
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
