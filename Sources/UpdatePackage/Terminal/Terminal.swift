//
//  PackagePreparation.swift
//  SwiftVisionTasks
//
//  Created by Pascal Burlet on 27.02.2025.
//


import Foundation

class Terminal {
    static func runCommand(_ command: String) {
        print(command)
    #if os(macOS)
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Use a dispatch queue to continuously read from the pipe
        let fileHandle = pipe.fileHandleForReading
        
        let queue = DispatchQueue(label: "com.process.output.queue", attributes: .concurrent)
        queue.async {
            while true {
                let data = fileHandle.readDataToEndOfFile()
                if data.count == 0 { break }
                if let str = String(data: data, encoding: .utf8) {
                    print(str, terminator: "")
                }
            }
        }
        
        process.launch()
        process.waitUntilExit()
    #endif
    }
}
