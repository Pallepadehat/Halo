// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HaloKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "HaloCore", targets: ["HaloCore"]),
        .library(name: "HaloProtocol", targets: ["HaloProtocol"]),
    ],
    targets: [
        .target(name: "HaloCore"),
        .target(name: "HaloProtocol", dependencies: ["HaloCore"]),
        .testTarget(name: "HaloCoreTests", dependencies: ["HaloCore"]),
        .testTarget(name: "HaloProtocolTests", dependencies: ["HaloProtocol"]),
    ]
)
