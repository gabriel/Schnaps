// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Schnaps",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Schnaps", targets: ["Schnaps"])],
    targets: [
        .target(name: "MeasurementCore"),
        .executableTarget(name: "Schnaps", dependencies: ["MeasurementCore"]),
        .testTarget(name: "MeasurementCoreTests", dependencies: ["MeasurementCore"])
    ]
)
