// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CameraSettings",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CUSB", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        .target(name: "UVCKit", dependencies: ["CUSB"]),
        .executableTarget(name: "uvc-probe", dependencies: ["UVCKit"]),
        .executableTarget(name: "CameraSettings", dependencies: ["UVCKit"]),
        .testTarget(name: "UVCKitTests", dependencies: ["UVCKit"], resources: [.copy("Fixtures")]),
    ]
)
