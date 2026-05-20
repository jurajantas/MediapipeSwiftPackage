//
//  MeasureEyes.swift
//  FaceTest
//
//  Created by Juraj Antas on 10/12/2023.
//

import Common
import Foundation
import MediaPipeTasksVision
import simd

public class MeasureEyes {
    // TODO: singletons must be handled some other way in Swift 6.0 mode.
    public nonisolated(unsafe) static let shared: MeasureEyes = MeasureEyes()
    
    var faceLandmarker: FaceLandmarkerHelper
    
    private init() {
        faceLandmarker = FaceLandmarkerHelper(
            modelPath: DefaultConstants.modelPath,
            numFaces: DefaultConstants.numFaces,
            minFaceDetectionConfidence: DefaultConstants.detectionConfidence,
            minFacePresenceConfidence: DefaultConstants.presenceConfidence,
            minTrackingConfidence: DefaultConstants.trackingConfidence,
            runningModel: .image,
            delegate: nil
        )

        NotificationCenter.default.addObserver(self, selector: #selector(measureEyesFromNotification(_:)), name: .measureEyesNotification, object: nil)
    }
    
    @objc func measureEyesFromNotification(_ notification: Notification) {
        guard let uiimage = notification.object as? UIImage else {
            return
        }
        
        if let eyeSize = computeEyeSizeInPixels(uiImage: uiimage) {
            let n = NSNumber(floatLiteral: eyeSize)
            NotificationCenter.default.post(name: .measureEyesResultNotification, object: n)
        } else {
            NotificationCenter.default.post(name: .measureEyesResultNotification, object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func computeEyeSizeInPixels(uiImage: UIImage) -> Double? {
        let result = faceLandmarker.detect(image: uiImage)
        guard let face = result?.faceLandmarkerResults.first, let face else {
            print("no eyes, returning nil")
            return nil
        }
        
        do {
            // eye left: 469 - 471   right: 474 - 476
            let leftDiameter = try measureIrisSize(
                face.faceLandmarks,
                orientation: uiImage.imageOrientation,
                imageSize: uiImage.size,
                pointAIndex: 469,
                pointBIndex: 471
            )
            
            let rightDiameter = try measureIrisSize(
                face.faceLandmarks,
                orientation: uiImage.imageOrientation,
                imageSize: uiImage.size,
                pointAIndex: 474,
                pointBIndex: 476
            )

            let leftRadius = leftDiameter / 2.0
            let rightRadius = rightDiameter / 2.0

            let size = Double((leftRadius + rightRadius) / 2.0)
            print("Eye size: \(size)")
            return size
        }
        catch {
            print("failed to measure eye size, returning nil")
            return nil
        }
    }
    
    /// Returns num pixels averaged from both eyes.
    func measureIrisSize(
        _ landmarks: [[NormalizedLandmark]],
        orientation: UIImage.Orientation,
        imageSize: CGSize,
        pointAIndex: Int,
        pointBIndex: Int
    ) throws -> CGFloat {
        guard let faceLandmarks = landmarks.first else {
            throw FaceDetectionError.noFace
        }
        
        guard faceLandmarks.indices.contains(pointAIndex),
              faceLandmarks.indices.contains(pointBIndex) else {
            throw FaceDetectionError.noFace // or a better `.invalidLandmarkIndex`
        }
        
        func orientedPoint(_ landmark: NormalizedLandmark) -> CGPoint {
            let x = CGFloat(landmark.x)
            let y = CGFloat(landmark.y)
            
            switch orientation {
            case .left:
                return CGPoint(x: y, y: 1 - x)
                
            case .right:
                return CGPoint(x: 1 - y, y: x)
                
            case .down:
                return CGPoint(x: 1 - x, y: 1 - y)
                
            default:
                return CGPoint(x: x, y: y)
            }
        }
        
        func pixelPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x * imageSize.width,
                y: point.y * imageSize.height
            )
        }
        
        let p1 = pixelPoint(orientedPoint(faceLandmarks[pointAIndex]))
        let p2 = pixelPoint(orientedPoint(faceLandmarks[pointBIndex]))
        
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        
        return sqrt(dx * dx + dy * dy)
    }

    
    static func measureEyeOpen(_ landmarks: [[NormalizedLandmark]], orientation: UIImage.Orientation, withImageSize imageSize: CGSize) throws -> (left: Float, right: Float) {
        guard !landmarks.isEmpty else {
            throw FaceDetectionError.noFace
        }
        
        
        var viewWidth = 320.0
        var viewHeight = 640.0
        var originX: CGFloat = 0
        var originY: CGFloat = 0
        let boundsWidth = 320.0
        let boundsHeight = 640.0
        
        if viewWidth / viewHeight > imageSize.width / imageSize.height {
            viewHeight = imageSize.height / imageSize.width  * boundsWidth
            originY = (boundsHeight - viewHeight) / 2
        } else {
            viewWidth = imageSize.width / imageSize.height * boundsHeight
            originX = (boundsWidth - viewWidth) / 2
        }
        
        for landmark in landmarks {
            var transformedLandmark: [CGPoint]!
            
            switch orientation {
            case .left:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.y), y: 1 - CGFloat($0.x))})
            case .right:
                transformedLandmark = landmark.map({CGPoint(x: 1 - CGFloat($0.y), y: CGFloat($0.x))})
            default:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
            }
            
            
            
            let dRight = distanceOfEyeOpeness(connections: FaceLandmarker.rightEyeConnections(), transformedLandmark: transformedLandmark, originX: originX, originY: originY, viewWidth: viewWidth, viewHeight: viewHeight)
            let dLeft = distanceOfEyeOpeness(connections: FaceLandmarker.leftEyeConnections(), transformedLandmark: transformedLandmark, originX: originX, originY: originY, viewWidth: viewWidth, viewHeight: viewHeight)
            
            print("Right: \(dRight) Left: \(dLeft)")
            return (left: dRight, right: dLeft)
        }
        
        
        
        return (left: 0.0, right: 0.0)
    }
    
    
    
    static private func distanceOfEyeOpeness(connections: [Connection], transformedLandmark: [CGPoint], originX: CGFloat, originY: CGFloat, viewWidth: CGFloat, viewHeight: CGFloat) -> Float {
        var startD: CGPoint = CGPoint(x: 0, y: 0)
        var endD: CGPoint = CGPoint(x: 0, y: 0)
        
        guard connections.count > 12 else {
            return 0.0
        }
        
        for (index,connection) in connections.enumerated() {
            let start = transformedLandmark[Int(connection.start)]
            //let end = transformedLandmark[Int(connection.end)]
            //cize index 4 a index 12 je moja ciara...
            if index == 4 {
                startD = CGPoint(x: CGFloat(start.x) * viewWidth + originX, y: CGFloat(start.y) * viewHeight + originY)
            }
            if index == 12 {
                endD = CGPoint(x: CGFloat(start.x) * viewWidth + originX, y: CGFloat(start.y) * viewHeight + originY)
            }
            
        }
        
        let sss = SIMD2<Float>(x: Float(startD.x), y: Float(startD.y))
        let sse = SIMD2<Float>(x: Float(endD.x), y: Float(endD.y))
        let vec: SIMD2<Float> = sss - sse
        let distance = simd_length(vec)

        //distance is in pixels..so I accept anything more than 7?
        return distance
    }
    //not used in latest version, we use irises only.
    static func computeCoordinatesForBlackoutEyeArea(_ landmarks: [[NormalizedLandmark]], orientation: UIImage.Orientation, withImageSize imageSize: CGSize) -> CGRect?
    {
        guard !landmarks.isEmpty else {
            return nil
        }
        
        for landmark in landmarks {
            var transformedLandmark: [CGPoint]!
            
            switch orientation {
            case .down:
                transformedLandmark = landmark.map({CGPoint(x: 1 - CGFloat($0.x), y: 1 - CGFloat($0.y))})
            case .left:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.y), y: 1 - CGFloat($0.x))})
            case .right:
                transformedLandmark = landmark.map({CGPoint(x: 1 - CGFloat($0.y), y: CGFloat($0.x))})
            default:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
            }
            var points: [CGPoint] = []
            
            
            points.append(contentsOf: FaceLandmarker.leftEyeConnections().map { connection in
                let start = transformedLandmark[Int(connection.start)]
                //let end = transformedLandmark[Int(connection.end)]
                let p1 = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                return p1
            })
            
            points.append(contentsOf: FaceLandmarker.rightEyeConnections().map { connection in
                let start = transformedLandmark[Int(connection.start)]
                //let end = transformedLandmark[Int(connection.end)]
                let p1 = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                return p1
            })
            
            points.append(contentsOf: FaceLandmarker.rightEyebrowConnections().map { connection in
                let start = transformedLandmark[Int(connection.start)]
                //let end = transformedLandmark[Int(connection.end)]
                let p1 = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                return p1
            })
            
            points.append(contentsOf: FaceLandmarker.leftEyebrowConnections().map { connection in
                let start = transformedLandmark[Int(connection.start)]
                //let end = transformedLandmark[Int(connection.end)]
                let p1 = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                return p1
            })
                        
            // Finding minimum and maximum x and y values
            let minX = points.min(by: { $0.x < $1.x })?.x ?? 0
            let minY = points.min(by: { $0.y < $1.y })?.y ?? 0
            let maxX = points.max(by: { $0.x < $1.x })?.x ?? 0
            let maxY = points.max(by: { $0.y < $1.y })?.y ?? 0

            // Creating a CGRect from the min and max points
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            return rect
        }

        return nil
    }

    
    static func computeCoordinatesForBlackoutIrisOnly(_ landmarks: [[NormalizedLandmark]], orientation: UIImage.Orientation, withImageSize imageSize: CGSize) -> (leftRect: CGRect?, rightRect: CGRect?, leftIrisString: String?, rightIrisString: String?)
    {
        guard !landmarks.isEmpty else {
            return (nil, nil, nil, nil)
        }
        
        for landmark in landmarks {
            var transformedLandmark: [CGPoint]!
            
            switch orientation {
            case .down:
                transformedLandmark = landmark.map({CGPoint(x: 1 - CGFloat($0.x), y: 1 - CGFloat($0.y))})
            case .left:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.y), y: 1 - CGFloat($0.x))})
            case .right:
                transformedLandmark = landmark.map({CGPoint(x: 1 - CGFloat($0.y), y: CGFloat($0.x))})
            default:
                transformedLandmark = landmark.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
            }
            var pointsLeft: [CGPoint] = []
            var pointsRight: [CGPoint] = []
            
            //left points
            for index in [474, 475, 476, 477] {
                let start = transformedLandmark[index]
                let point = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                pointsLeft.append(point)
            }
            
            for index in [469, 470, 471, 472] {
                let start = transformedLandmark[index]
                let point = CGPoint(x: CGFloat(start.x) * imageSize.width, y: CGFloat(start.y) * imageSize.height)
                pointsRight.append(point)
            }
            
            //internal function to compute rect of points.
            func bbboxFromPoints(_ points: [CGPoint], size: CGSize ) -> CGRect {
                // Finding minimum and maximum x and y values
                let minX = points.min(by: { $0.x < $1.x })?.x ?? 0
                let minY = points.min(by: { $0.y < $1.y })?.y ?? 0
                let maxX = points.max(by: { $0.x < $1.x })?.x ?? 0
                let maxY = points.max(by: { $0.y < $1.y })?.y ?? 0

                // Creating a CGRect from the min and max points
                let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    
                //compute middle mid.x mid.y, extend by 128 or 256
                let rectRes = CGRect(x: rect.midX - size.width, y: rect.midY - size.height, width: size.width*2.0, height: size.height*2.0)
                
                return rectRes
            }
            
            let size = CGSize(width: 128, height: 128)
            let leftRect = bbboxFromPoints(pointsLeft, size: size)
            let rightRect = bbboxFromPoints(pointsRight, size: size)
            
            let leftIrisString: String = "[[\(pointsLeft[0].x),\(pointsLeft[0].y)],[\(pointsLeft[1].x),\(pointsLeft[1].y)],[\(pointsLeft[2].x),\(pointsLeft[2].y)],[\(pointsLeft[3].x),\(pointsLeft[3].y)]]"
            let rightIrisString: String = "[[\(pointsRight[0].x),\(pointsRight[0].y)],[\(pointsRight[1].x),\(pointsRight[1].y)],[\(pointsRight[2].x),\(pointsRight[2].y)],[\(pointsRight[3].x),\(pointsRight[3].y)]]"
            
            return (leftRect, rightRect, leftIrisString, rightIrisString)
        }

        return (nil,nil, nil, nil)
    }

}
