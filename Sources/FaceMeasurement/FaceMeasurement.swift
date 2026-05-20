// The Swift Programming Language
// https://docs.swift.org/swift-book

// import Common
import SwiftUI
import MediaPipeTasksVision

// when you feel like to replace notification center..this could be the way
// create protocol that defines functionality..
// make sure that only target is using final implementation of this
// so no problem with linker in previews.


// TODO: this is good idea. Finalize it. This will allow you to drop notifications.

// This is real implementation. Not a mock.
/*
public final class FaceMeasurement: FaceLandmarkerProvider {
    
    // load the face model
    // allow to do the stuff
    
    public func doBlackout(videoURL: URL) async throws -> URL {
        throw FaceDetectionError.noFace //
    }
    
    public func measureIrisDistance(from image: UIImage) async throws -> Double {
        1.2
    }
}
 */


public extension Notification.Name {
    static let doBlackoutNotification = Notification.Name("doBlackoutNotification") // video URL vstup
    static let blackoutDoneNotification = Notification.Name("blackoutDoneNotification") //URL video vystup
 
    static let measureEyesNotification = Notification.Name("measureEyesNotification") // UIImage vstup
    static let measureEyesResultNotification = Notification.Name("measureEyesResultNotification") // Double
}

