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
        .library(name: "HaloHookBridge", targets: ["HaloHookBridge"]),
        .library(name: "HaloAgents", targets: ["HaloAgents"]),
        .library(name: "HaloTransport", targets: ["HaloTransport"]),
        .library(name: "HaloMetrics", targets: ["HaloMetrics"]),
        .library(name: "HaloTrackpad", targets: ["HaloTrackpad"]),
        .library(name: "HaloInput", targets: ["HaloInput"]),
        .library(name: "HaloDashboard", targets: ["HaloDashboard"]),
        .library(name: "HaloDesktop", targets: ["HaloDesktop"]),
    ],
    targets: [
        .target(name: "HaloCore"),
        .target(name: "HaloProtocol", dependencies: ["HaloCore"]),
        .target(name: "HaloHookBridge", dependencies: ["HaloCore"]),
        .target(name: "HaloAgents", dependencies: ["HaloCore", "HaloHookBridge"]),
        .target(name: "HaloTransport"),
        .target(name: "HaloMetrics", dependencies: ["HaloCore"]),
        .target(name: "HaloTrackpad", dependencies: ["HaloProtocol"]),
        .target(name: "HaloInput", dependencies: ["HaloProtocol"]),
        .target(name: "HaloDashboard"),
        .target(name: "HaloDesktop", dependencies: ["HaloCore", "HaloInput"]),
        .testTarget(name: "HaloCoreTests", dependencies: ["HaloCore"]),
        .testTarget(name: "HaloProtocolTests", dependencies: ["HaloProtocol"]),
        .testTarget(name: "HaloHookBridgeTests", dependencies: ["HaloHookBridge"]),
        .testTarget(name: "HaloAgentsTests", dependencies: ["HaloAgents"]),
        .testTarget(name: "HaloTransportTests", dependencies: ["HaloTransport"]),
        .testTarget(name: "HaloMetricsTests", dependencies: ["HaloMetrics"]),
        .testTarget(name: "HaloTrackpadTests", dependencies: ["HaloTrackpad"]),
        .testTarget(name: "HaloInputTests", dependencies: ["HaloInput"]),
        .testTarget(name: "HaloDashboardTests", dependencies: ["HaloDashboard"]),
        .testTarget(name: "HaloDesktopTests", dependencies: ["HaloDesktop"]),
    ]
)
