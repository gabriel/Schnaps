// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Schnaps",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Schnaps", targets: ["Schnaps"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .target(name: "MeasurementCore"),
        .executableTarget(name: "Schnaps", dependencies: ["MeasurementCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "MeasurementCoreTests", dependencies: ["MeasurementCore"])
    ]
)
