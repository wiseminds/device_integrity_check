// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "device_integrity_check",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "device-integrity-check", targets: ["device_integrity_check"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "device_integrity_check",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/device_integrity_check"
        )
    ]
)
