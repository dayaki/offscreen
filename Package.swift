// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Offscreen",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Offscreen",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Offscreen",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "OffscreenTests",
            dependencies: ["Offscreen"],
            path: "Tests/OffscreenTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
