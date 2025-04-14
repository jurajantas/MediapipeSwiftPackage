//
//  UpdatePackage.swift
//  SwiftVisionTasks
//
//  Created by Pascal Burlet on 27.02.2025.
//

import Foundation
import System

@main
@available(macOS 16.0.0, *)
struct UpdatePackage {
    static let fileManager = FileManager.default

    static func main() async throws {
        downloadPods()
        try moveStaticLibraries()
        try copyMediaPipeTasksCommonXCFramework()
        try copyMediaPipeTasksVisionXCFramework()
        try copyMediaPipeTasksVisionInfoPlist()
        try deletePodsDir()
        try buildCommonGraphXCFramework()
        try copyCommonGraphXCFramework()
        try removeTemporaryFiles()
        try updateTaskModels()
    }
    
    private static func downloadPods() {
        let podPath = "/usr/local/bin/pod"
        
        let temporaryDirectory = Definitions.temporaryProjectRoot
        
        Terminal.runCommand(
            """
            export LANG=en_US.UTF-8;
            \(podPath) install --project-directory=\(temporaryDirectory);
            """
        )
    }
    
    private static func moveStaticLibraries() throws {
        let staticLibrariesDir = Definitions.temporaryProjectRoot
            .appending(path: "Pods")
            .appending(path: "MediaPipeTasksCommon")
            .appending(path: "frameworks")
            .appending(path: "graph_libraries")

        try fileManager
            .copyContents(
                of: URL(fileURLWithPath: staticLibrariesDir.path),
                to: URL(fileURLWithPath: Definitions.temporaryProjectRoot.path)
            )
    }
    
    private static func copyMediaPipeTasksCommonXCFramework() throws {
        let mediaPipeTasksCommonXCFrameworkURL = Definitions.temporaryProjectRoot
            .appending(path: "Pods")
            .appending(path: "MediaPipeTasksCommon")
            .appending(path: "frameworks")
            .appending(path: "MediaPipeTasksCommon.xcframework")
        let temporaryProjectCommonFrameworkURL = Definitions.temporaryProjectRoot
            .appending(path: "MediaPipeTasksCommon.xcframework")
        let dependenciesTasksCommonFrameworkURL = Definitions.packageRoot
            .appending(path: "Dependencies")
            .appending(path: "MediaPipeTasksCommon.xcframework")
            
        try fileManager
            .copyContents(
                of: URL(fileURLWithPath: mediaPipeTasksCommonXCFrameworkURL.path),
                to: URL(fileURLWithPath: temporaryProjectCommonFrameworkURL.path)
            )
        try fileManager
            .copyContents(
                of: URL(fileURLWithPath: mediaPipeTasksCommonXCFrameworkURL.path),
                to: URL(fileURLWithPath: dependenciesTasksCommonFrameworkURL.path)
            )
    }

    private static func copyMediaPipeTasksVisionXCFramework() throws {
        let mediaPipeTasksVisionXCFrameworkURL = Definitions.temporaryProjectRoot
            .appending(path: "Pods")
            .appending(path: "MediaPipeTasksVision")
            .appending(path: "frameworks")
            .appending(path: "MediaPipeTasksVision.xcframework")
        
        let dependenciesTasksVisionFrameworkURL = Definitions.packageRoot
            .appending(path: "Dependencies")
            .appending(path: "MediaPipeTasksVision.xcframework")
            
        
        try fileManager
            .copyContents(
                of: URL(fileURLWithPath: mediaPipeTasksVisionXCFrameworkURL.path),
                to: URL(fileURLWithPath: dependenciesTasksVisionFrameworkURL.path)
            )
    }
    
    private static func copyMediaPipeTasksVisionInfoPlist() throws {
        guard let url = Bundle.module.url(forResource: "MediaPipeVision.Info", withExtension: "plist") else {
            return
        }
        let data = try Data(contentsOf: url)
        
        let iOSFrameworkInfoPlist = Definitions.packageRoot
            .appending(path: "Dependencies")
            .appending(path: "MediaPipeTasksVision.xcframework")
            .appending(path: "ios-arm64")
            .appending(path: "MediaPipeTasksVision.framework")
            .appending(path: "Info.plist")
        
        let simFrameworkInfoPlist = Definitions.packageRoot
            .appending(path: "Dependencies")
            .appending(path: "MediaPipeTasksVision.xcframework")
            .appending(path: "ios-arm64_x86_64-simulator")
            .appending(path: "MediaPipeTasksVision.framework")
            .appending(path: "Info.plist")
        
        try data.write(to: URL(fileURLWithPath: iOSFrameworkInfoPlist.path))
        try data.write(to: URL(fileURLWithPath: simFrameworkInfoPlist.path))
    }
    
    private static func deletePodsDir() throws {
        let podsURL = Definitions.temporaryProjectRoot
            .appending(path: "Pods")
        
        try FileManager.default.removeItem(at: URL(fileURLWithPath: podsURL.path))
    }
    
    private static func buildCommonGraphXCFramework() throws {
        let projectFileURL = Definitions.temporaryProjectRoot
            .appending(path: "MediaPipeCommonGraphLibraries.xcodeproj")
        let buildFolder = Definitions.temporaryProjectRoot
            .appending(path: "Builds")

        let buildiOSFrameworkCommand =
            """
            xcodebuild build \
                -project \(projectFileURL.path) \
                -scheme MediaPipeCommonGraphLibraries \
                -configuration Release \
                -sdk iphoneos \
                BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
                SYMROOT=\(buildFolder)
            """
        
        let buildSimFrameworkCommand =
        """
        xcodebuild build \
              -project \(projectFileURL.path) \
              -scheme MediaPipeCommonGraphLibraries \
              -configuration Release \
              -sdk iphonesimulator \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
              SYMROOT=\(buildFolder)
        """
        
        let buildXCFrameworkCommand =
        """
        xcodebuild -create-xcframework \
          -framework \(buildFolder)/Release-iphoneos/MediaPipeCommonGraphLibraries.framework \
          -framework \(buildFolder)/Release-iphonesimulator/MediaPipeCommonGraphLibraries.framework \
          -output \(buildFolder)/MediaPipeCommonGraphLibraries.xcframework
        """
        
        Terminal.runCommand(buildiOSFrameworkCommand)
        Terminal.runCommand(buildSimFrameworkCommand)
        Terminal.runCommand(buildXCFrameworkCommand)
    }
    
    private static func copyCommonGraphXCFramework() throws {
        let buildFolder = Definitions.temporaryProjectRoot
            .appending(path: "Builds")
        let sourceXCframeworkPath = buildFolder
            .appending(path: "MediaPipeCommonGraphLibraries.xcframework")
        let dependenciesTasksCommonGraphXCFramework = Definitions.packageRoot
            .appending(path: "Dependencies")
            .appending(path: "MediaPipeCommonGraphLibraries.xcframework")
        try FileManager.default
            .copyContents(
                of: URL(fileURLWithPath: sourceXCframeworkPath.path),
                to: URL(fileURLWithPath: dependenciesTasksCommonGraphXCFramework.path)
            )
    }
    
    private static func removeTemporaryFiles() throws {
        let fileManager = FileManager.default

        let buildFolder = Definitions.temporaryProjectRoot
            .appending(path: "Builds")
        let commonGraphStaticLibiOS = Definitions.temporaryProjectRoot
            .appending(path: "libMediaPipeTasksCommon_device_graph.a")
        let commonGraphStaticLibSim = Definitions.temporaryProjectRoot
            .appending(path: "libMediaPipeTasksCommon_simulator_graph.a")
        let mediaPipeTasksCommonXCFramework = Definitions.temporaryProjectRoot
            .appending(path: "MediaPipeTasksCommon.xcframework")
        try fileManager.removeItem(at: URL(fileURLWithPath: buildFolder.path))
        try fileManager.removeItem(at: URL(fileURLWithPath: commonGraphStaticLibiOS.path))
        try fileManager.removeItem(at: URL(fileURLWithPath: commonGraphStaticLibSim.path))
        try fileManager.removeItem(at: URL(fileURLWithPath: mediaPipeTasksCommonXCFramework.path))
    }
    
    private static func updateTaskModels() throws {
        let exampleAppRoot = Definitions.packageRoot
            .appending(path: "ExampleApp")
            
        let exampleAppProjectRoot = exampleAppRoot
            .appending(path: "PoseLandmarker")
        
        let lightModelTaskModelFile = exampleAppProjectRoot
            .appending(path: "pose_landmarker_full.task")
        let heavyModelTaskModelFile = exampleAppProjectRoot
            .appending(path: "pose_landmarker_heavy.task")
        let liteModelTaskModelFile = exampleAppProjectRoot
            .appending(path: "pose_landmarker_lite.task")
        
        try? fileManager.removeItem(at: URL(fileURLWithPath: lightModelTaskModelFile.path))
        try? fileManager.removeItem(at: URL(fileURLWithPath: heavyModelTaskModelFile.path))
        try? fileManager.removeItem(at: URL(fileURLWithPath: liteModelTaskModelFile.path))
        
        Terminal.runCommand(
            """
            cd \(exampleAppRoot);
            ./download_models.sh;
            """
        )
    }
}

