//
//  TakenVideoDetailModel.swift
//  OptikosPrime
//
//  Created by Juraj Antas on 08/03/2024.
//

//I need UIImage for mediapipe lib. yeah, it is stupid. google dev sucks.
import UIKit
import UniformTypeIdentifiers

enum DefaultConstants {
    static let numFaces = 1
    static let detectionConfidence: Float = 0.5
    static let presenceConfidence: Float = 0.5
    static let trackingConfidence: Float = 0.5
    static let outputFaceBlendshapes: Bool = false
    static let modelPath: String? = Bundle.main.path(forResource: "face_landmarker", ofType: "task")
}

public enum VerificationErrors: String {
    case noFace
    case noEyes
    case decodingError
    case noError
    
    var description: String {
        switch self {
        case .noFace:
            "No face"
        case .noEyes:
            "No eyes"
        case .decodingError:
            "Decoding error"
        case .noError:
            "No error"
        }
    }
}

public enum VerificationKeys: String {
    case error
    case videoPath
    case leftEye
    case rightEye
}

protocol TakenVideoDetailModelDelegate: AnyObject {
    func viewModelUpdated(error: Bool)
    func imageVerified(faceInImage: Bool, openEyes: Bool, noBlur: Bool)
}

public class TakenVideoDetailModel: FaceLandmarkerHelperDelegate {
    
    public nonisolated(unsafe) static let shared = TakenVideoDetailModel()
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(doBlackoutFromNotification(_:)), name: .doBlackoutNotification, object: nil)
        //create new URL for video? certainly
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    weak var delegate: TakenVideoDetailModelDelegate?
    
    //snapshot from the video
    var videoTools: VideoBlackout?
    var videoURL: URL?
    var blackoutVideoURL: URL?
    var image: UIImage?
    var cameraMode: CameraOrientation = .portrait //TODO: allow all orientations
    
    var imageVerificationResults: (faceInImage: Bool, openEyes: Bool, noBlur: Bool) = (false, false, false)
    
    //face detection
    private var faceLandmarkerHelper: FaceLandmarkerHelper?
    private var numFaces = DefaultConstants.numFaces
    private var detectionConfidence = DefaultConstants.detectionConfidence
    private var presenceConfidence = DefaultConstants.presenceConfidence
    private var trackingConfidence = DefaultConstants.trackingConfidence
    private let modelPath = DefaultConstants.modelPath
    
    //private var eyesRect: CGRect?
    
    private var eyeLeftRect: CGRect?
    private var eyeRightRect: CGRect?
    var leftIrisString: String?
    var rightIrisString: String?
    
    private var imageMetadata: NSMutableDictionary?
    
    public func doBlackout(for videoURL: URL) {
        
    }
    
    @objc func doBlackoutFromNotification(_ notification: Notification) {
        guard let videoURL = notification.object as? URL else {
            return
        }
        
        let filename = videoURL.lastPathComponent
        let newFilename = "blackout-" + filename
        blackoutVideoURL = videoURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        
        guard let blackoutVideoURL else {
            return
        }
        
        do {
            self.videoTools = try VideoBlackout(inputPath: videoURL, outputPath: blackoutVideoURL)
        }
        catch {
            self.videoTools = nil //hmm, now what?!
            postErrorFromVerification(error: .decodingError)
            return
        }
        
        let imageForFrameTime: Double? = 6.0
        if let uiimage = self.videoTools?.decodeOneKeyImage(input: videoURL, forFrameTime: imageForFrameTime) {

            self.image = uiimage

            let results = verifyImage(uiimage)
            
            
            
            if results.faceInImage == false {
                postErrorFromVerification(error: .noFace)
                return
            }
            if results.openEyes == false {
                postErrorFromVerification(error: .noEyes)
                return
            }
            if results.noBlur == false {
                postErrorFromVerification(error: .noEyes)
                return
            }
            
            guard let leftIrisString, let rightIrisString else {
                postErrorFromVerification(error: .decodingError)
                return
            }
            
            //do the blackout
            blackoutVideoExceptEyes(videoURL: blackoutVideoURL) { [weak self] newUrl in
                if let newUrl {
                    
                        self?.postSuccessFromVerification(url: newUrl)
                        return
                    
                }
                else {
                    self?.postErrorFromVerification(error: .decodingError)
                    return
                }
            }
            
        }
        else {
            postErrorFromVerification(error: .decodingError)
            return
        }
    }
    
    func postSuccessFromVerification(url: URL) {
        var dict: [String: String] = [:]
        
        dict[VerificationKeys.error.rawValue] = VerificationErrors.noError.rawValue
        dict[VerificationKeys.leftEye.rawValue] = leftIrisString
        dict[VerificationKeys.rightEye.rawValue] = rightIrisString
        dict[VerificationKeys.videoPath.rawValue] = url.absoluteString
        
        let safeDict = dict
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .blackoutDoneNotification, object: nil, userInfo: safeDict)
        }
    }
    
    func postErrorFromVerification(error: VerificationErrors) {
        var dict: [String: String] = [:]
        
        dict["error"] = error.rawValue
        
        let safeDict = dict
    
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .blackoutDoneNotification, object: nil, userInfo: safeDict)
        }
    }

    
    func canContinueQualityIsGood() -> Bool {
        if imageVerificationResults.faceInImage == true,
           imageVerificationResults.openEyes == true,
           imageVerificationResults.noBlur == true {
            return true
        }
        
        return false
    }
    
    func blackoutVideoExceptEyes(videoURL: URL, completion: @escaping @Sendable (URL?) -> Void) {
        guard let eyeLeftRect = eyeLeftRect,
              let eyeRightRect = eyeRightRect,
              let image = image
        else {
            completion(nil)
            return
        }
        #warning("Tu vies nastavit cas od ktoreho sa zacina ukladat blackoutnute video -> fromTime")
        videoTools?.startProcess(cameraOrientation: cameraMode, size: image.size, leftEyesRect: eyeLeftRect, rightEyeRect: eyeRightRect, fromTime: 5.0, completion: { result in
            switch result {
            case .success(let url):
                print("\(url)")
                completion(url)
                
            case .failure(let error):
                print("\(error)")
                completion(nil)
            }
        })
    }
    
    func blackoutImageExceptEyes(image: UIImage) -> UIImage {
        guard let eyeLeftRect = eyeLeftRect,
              let eyeRightRect = eyeRightRect
        else {
            return image
        }
        
        if let blackedImage = image.applyBlackMaskToImage(keepImageInRect: [eyeLeftRect, eyeRightRect]) {
            return blackedImage
        }
        else {
            return image
        }
    }
    
    func makeJsonFromEyeRects(rect: CGRect) -> String? {
        //{"x": 23, "y": 43, "width": 452, "height": 432}
        struct RectToEncode: Encodable {
            var x: Int
            var y: Int
            var width: Int
            var height: Int
        }
        
        let dataToEncode = RectToEncode(x: Int(rect.origin.x), y: Int(rect.origin.y), width: Int(rect.width), height: Int(rect.height))
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(dataToEncode) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func verifyImage() {
        if let image = self.image {
            let results = verifyImage(image)
            delegate?.imageVerified(faceInImage: results.faceInImage, openEyes: results.openEyes, noBlur: results.noBlur)
        }
        else {
            delegate?.imageVerified(faceInImage: false, openEyes: false, noBlur: false)
        }
    }
    
    func verifyImage(_ uiImage: UIImage) -> (faceInImage: Bool, openEyes: Bool, noBlur: Bool) {
        faceLandmarkerHelper = FaceLandmarkerHelper(
            modelPath: modelPath,
            numFaces: numFaces,
            minFaceDetectionConfidence: detectionConfidence,
            minFacePresenceConfidence: presenceConfidence,
            minTrackingConfidence: trackingConfidence,
            runningModel: .image,
            delegate: self)
        
        
        let result = faceLandmarkerHelper?.detect(image: uiImage)
        
        if let face = result?.faceLandmarkerResults.first,
           let face = face {
            do {
                let results = try MeasureEyes.measureEyeOpen(face.faceLandmarks, orientation: uiImage.imageOrientation, withImageSize: uiImage.size)
                
                let leftEyeOpen: Bool = results.left > 3 ? true : false
                let rightEyeOpen: Bool = results.right > 3 ? true : false
                
                //compute coordinates, those are later used to blackout image to eyes only.
                let mediaData = MeasureEyes.computeCoordinatesForBlackoutIrisOnly(face.faceLandmarks, orientation: uiImage.imageOrientation, withImageSize: uiImage.size)
                eyeLeftRect = mediaData.leftRect
                eyeRightRect = mediaData.rightRect
                
                //old string format...not usefull
                //leftIrisString = mediaData.leftIrisString
                //rightIrisString = mediaData.rightIrisString
                leftIrisString = makeJsonFromEyeRects(rect: mediaData.leftRect ?? .zero)
                rightIrisString = makeJsonFromEyeRects(rect: mediaData.rightRect ?? .zero)
                
                //now we have more than one rect..
                //eyesRect = MeasureEyes.computeCoordinatesForBlackoutEyeArea(face.faceLandmarks, orientation: uiImage.imageOrientation, withImageSize: uiImage.size)
                
                return (true, leftEyeOpen && rightEyeOpen, true)
            }
            catch {
                return (false, false, true)
            }
        }
        
        return (false, false, true)
    }
    
    
    //MARK: - Facelandmarker delegate
    func faceLandmarkerHelper(_ faceLandmarkerHelper: FaceLandmarkerHelper, didFinishDetection result: ResultBundle?, error: Error?) {
        //intentionaly no implementation
    }
    
}


//MARK: - Extension on UIImage for blackout
extension UIImage {
    func applyBlackMaskToImage(keepImageInRect maskRects: [CGRect]) -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setBlendMode(.normal)
        
        UIColor.black.setFill()
        let background = UIBezierPath(rect: CGRect(origin: CGPoint(x: 0, y: 0), size: self.size))
        background.fill()
        background.stroke()
        
        //stroke two white boxes from maskRects
        UIColor.white.setFill()
        for maskRect in maskRects {
            let whiteRect = UIBezierPath(rect: maskRect)
            whiteRect.fill()
            whiteRect.stroke()
        }
        
        
        self.draw(at: .zero, blendMode: .multiply, alpha: 1.0)
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resultImage
    }
    
    func applyNoMaskToImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setBlendMode(.normal)
        
        self.draw(at: .zero, blendMode: .normal, alpha: 1.0)
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resultImage
    }
}
