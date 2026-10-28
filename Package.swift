// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Schnap",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Schnap", targets: ["Schnap"])],
    targets: [
        .target(name: "MeasurementCore"),
        .executableTarget(name: "Schnap", dependencies: ["MeasurementCore"]),
        .testTarget(name: "MeasurementCoreTests", dependencies: ["MeasurementCore"])
    ]
)
