// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "try",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "try", targets: ["try"])
    ],
    targets: [
        .target(name: "TryCore"),
        .target(name: "TryTerminal", dependencies: ["TryCore"]),
        .target(name: "TryGit", dependencies: ["TryCore"]),
        .executableTarget(
            name: "try",
            dependencies: ["TryCore", "TryTerminal", "TryGit"]
        ),
        .testTarget(name: "TryCoreTests", dependencies: ["TryCore"]),
        .testTarget(name: "TryTerminalTests", dependencies: ["TryTerminal"]),
    ]
)
