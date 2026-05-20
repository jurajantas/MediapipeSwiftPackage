//
//  VideoBlackout.swift
//  OptikosPrime
//
//  Created by Juraj Antas on 06/03/2024.
//

import Foundation
import AVFoundation
import UIKit

enum VideoEncodingError: Error {
    case failedToDecodeImage
    case failedToWrite
}

enum CameraOrientation {
    case portrait
    case landscape
}

class VideoBlackout {
    private var videoInputURL: URL
    private var videoOutputURL: URL
    private var assetWriter: AVAssetWriter
    private var videoWriterInput: AVAssetWriterInput!
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var videoFramerate: Double?
    private var currentTime: Double = 0.0
    private var startTime: TimeInterval = 0.0
    
    //HACK: For some reason now we don't want black out. BUT I also don't want to change this code every time.
    private var doTheBlackOut: Bool = false
    
    init(inputPath: URL, outputPath: URL) throws {
        videoInputURL = inputPath
        videoOutputURL = outputPath
        assetWriter = try AVAssetWriter(outputURL: outputPath, fileType: AVFileType.mov)
    }
    
    func startProcess(cameraOrientation: CameraOrientation, size: CGSize, leftEyesRect: CGRect, rightEyeRect: CGRect, fromTime: TimeInterval, completion: @escaping @Sendable (Result<URL, VideoEncodingError>) -> Void) {
        
        startTime = fromTime
        //TODO: you may want to rewrite this with await async..when xcode 16 hits the stores.
        initializeVideoEncoder(size: size)
        let outputUrl = self.videoOutputURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {return}
            doTheVideoBlackout(cameraOrientation: cameraOrientation, input: videoInputURL, leftEyesRect: leftEyesRect, rightEyeRect: rightEyeRect)
            self.finilizeVideoEncoding { error in
                DispatchQueue.main.async {
                    if error != nil {
                        completion(.failure(.failedToWrite))
                    }
                    else {
                        completion(.success(outputUrl))
                    }
                }
            }
        }
    }
    
    private func initializeVideoEncoder(size: CGSize) {
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
        
        assetWriter.canAdd(videoWriterInput)
        assetWriter.add(videoWriterInput)
        
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    func addVideoFrame(image: UIImage) {
        guard let frameRate = videoFramerate else {
            return
        }
        
        let oneStepInSeconds = 1.0 / frameRate
        
        guard let pixelBuffer = pixelBuffer(from: image) else {
            return
        }
            
        let presentationTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: 600)
            
    
        while !videoWriterInput.isReadyForMoreMediaData {
            // Wait until the input is ready
            Thread.sleep(forTimeInterval: 0.016) //60fps
        }
        /* another aproach..try later..
         myAVAssetWriterInput.requestMediaDataWhenReady(on: queue) {
             while myAVAssetWriterInput.isReadyForMoreMediaData {
                 let nextSampleBuffer = copyNextSampleBufferToWrite()
                 if let nextSampleBuffer = nextSampleBuffer {
                     // you have another frame to add
                     myAVAssetWriterInput.append(nextSampleBuffer)
                 } else {
                     // finished to add frames
                     myAVAssetWriterInput.markAsFinished()
                     break
                 }
             }
         })
         */
            
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        
        currentTime += oneStepInSeconds
    }
    
    
    private func finilizeVideoEncoding(completion: @escaping  (Error?) -> Void) {
        videoWriterInput.markAsFinished()
        assetWriter.finishWriting { [weak self] in
            guard let self = self else {
                return completion(nil)
            }
            
            if assetWriter.status == .failed {
                completion(assetWriter.error)
            }
            else {
                completion(nil)
            }
        }
    }
    
    func decodeOneKeyImage(input videoURL: URL, forFrameTime: Double? = nil) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        let duration = CMTimeGetSeconds(asset.duration)
        let timeForFrame: Double
        if let forFrameTime = forFrameTime {
            var t = forFrameTime
            if t > duration {
                t = duration
            }
            timeForFrame = t
        }
        else {
            timeForFrame = duration * 2.0/3.0
        }
        let timescale = asset.duration.timescale
        //hm, this does not work well.
        let frameRate = asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 30.0
        videoFramerate = Double(frameRate)
        
        let time = CMTime(seconds: timeForFrame, preferredTimescale: timescale)
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            return image
        }
        catch let error
        {
            print("Something bad \(error)")
        }
        
        return nil
    }
    
    //input video url
    //output video url
    //Whole video will be blacked out except eyes
    //NOTE: decompression with let imageGenerator = AVAssetImageGenerator(asset: asset) take too much memory. Do not use it.
    func doTheVideoBlackout(cameraOrientation: CameraOrientation, input videoURL: URL, leftEyesRect: CGRect, rightEyeRect: CGRect) {
     
        let asset = AVAsset(url: videoURL)
        
        guard let reader = try? AVAssetReader(asset: asset) else {
            return
        }
        
        let videoTrack = asset.tracks(withMediaType: .video).first
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: outputSettings)
        
        reader.add(trackOutput)
        reader.startReading()
        
        guard let videoFramerate = videoFramerate else {
            return
        }
        
        let framesToSkip = Int(startTime * videoFramerate)
        var frameCounter: Int = 0
        var frameCounterOfEncodedFrames: Int = 0
        var stop: Bool = false
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
        
            if stop {
                return
            }
        
            frameCounter += 1
            if frameCounter < framesToSkip {
                continue
            }
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                //autoreleasepool is here because I need to dealloc UIImages sooner. Otherwise app crashes on low memory.
                autoreleasepool {
                    // Code that creates autoreleased objects.
                    let image: UIImage
                    switch cameraOrientation {
                    case .portrait:
                        image = UIImage(cgImage: cgImage, scale: 0, orientation: .right)
                    case .landscape:
                        image = UIImage(cgImage: cgImage, scale: 0, orientation: .down)
                    }
                    
                    if doTheBlackOut {
                        let blackImage = image.applyBlackMaskToImage(keepImageInRect: [leftEyesRect, rightEyeRect])
                        guard let blackImage = blackImage else {
                            return
                        }
                        
                        addVideoFrame(image: blackImage)
                    }
                    else {
                        let noBlackOutImage = image.applyNoMaskToImage()
                        guard let noBlackOutImage else {
                            return
                        }
                        addVideoFrame(image: noBlackOutImage)
                    }
                    
                    frameCounterOfEncodedFrames += 1
                    
                    //we want to encode only 20 frames, so resulting video is smaller in size. and lets hope for the best...
                    if frameCounterOfEncodedFrames >= 25 {
                        //haha you can not return or break here..wtf?!
                        //return //labeled break can not be used here..we are inside autorelease pool. shame..but ok.
                        stop = true
                    }
                }
                
            }
        }
    }
    
    
    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(image.size.width),
                                         Int(image.size.height),
                                         kCVPixelFormatType_32ARGB,
                                         options as CFDictionary,
                                         &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: Int(image.size.width),
                                height: Int(image.size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let cgImage = image.cgImage, let cgContext = context else {
            return nil
        }
        
        cgContext.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        return buffer
    }
}
