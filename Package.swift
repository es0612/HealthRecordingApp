// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HealthRecordingApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "HealthRecordingApp",
            path: "app/HealthRecordingApp",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "HealthRecordingApp.entitlements",
                "HealthRecordingAppApp.swift",
                "ContentView.swift"
            ]
        ),
        .testTarget(
            name: "HealthRecordingAppTests",
            dependencies: [
                "HealthRecordingApp",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests"
        )
    ]
)