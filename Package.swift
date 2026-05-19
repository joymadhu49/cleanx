// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CleanX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanX", targets: ["CleanX"]),
    ],
    targets: [
        .executableTarget(
            name: "CleanX",
            path: "Sources/CleanX",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
    ]
)
