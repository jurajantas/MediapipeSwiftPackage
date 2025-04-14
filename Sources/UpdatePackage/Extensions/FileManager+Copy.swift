//
//  FileManager+Copy.swift
//  SwiftVisionTasks
//
//  Created by Pascal Burlet on 03.03.2025.
//

import Foundation

extension FileManager {
    func copyContents(of sourceURL: URL, to destinationURL: URL) throws {
        guard fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "FileManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source folder does not exist"])
        }
        
        if !fileExists(atPath: destinationURL.path) {
            try createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }
        
        let contents = try contentsOfDirectory(atPath: sourceURL.path)
        
        for item in contents {
            let sourceItem = sourceURL.appendingPathComponent(item)
            let destinationItem = destinationURL.appendingPathComponent(item)
            
            if fileExists(atPath: destinationItem.path) {
                try removeItem(at: destinationItem)
            }
            
            try copyItem(at: sourceItem, to: destinationItem)
        }
    }
}
