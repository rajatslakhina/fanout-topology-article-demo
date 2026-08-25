// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FanOutPlanner",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FanOutPlanner", targets: ["FanOutPlanner"]),
        .library(name: "FanOutPlannerUI", targets: ["FanOutPlannerUI"]),
    ],
    targets: [
        .target(name: "FanOutPlanner"),
        .target(name: "FanOutPlannerUI", dependencies: ["FanOutPlanner"]),
        .testTarget(name: "FanOutPlannerTests", dependencies: ["FanOutPlanner"]),
    ]
)
