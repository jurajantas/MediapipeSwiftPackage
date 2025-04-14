// swift-tools-version:5.9
import PackageDescription
import Foundation

let package = Package(
    name: "SwiftTasksVision",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftTasksVision",
            targets: ["SwiftTasksVision"]
        ),
        .executable(
            name: "UpdatePackage",
            targets: ["UpdatePackage"]
        )
    ],
    targets: [
        .target(
            name: "SwiftTasksVision",
            dependencies: ["MediaPipeCommonGraphLibraries", "MediaPipeTasksVision"],
            linkerSettings: [
                .unsafeFlags(["-ObjC"])
            ]
        ),
        .binaryTarget(
            name: "MediaPipeTasksVision",
            path: "Dependencies/MediaPipeTasksVision.xcframework"
        ),
        .binaryTarget(
            name: "MediaPipeCommonGraphLibraries",
            path: "Dependencies/MediaPipeCommonGraphLibraries.xcframework"
        ),
        .binaryTarget(
            name: "MediaPipeTasksCommon",
            path: "Dependencies/MediaPipeTasksCommon.xcframework"
        ),
        .executableTarget(
            name: "UpdatePackage",
            resources: [
                .process("Resources/MediaPipeVision.Info.plist")
            ]
        ),
    ]
)
