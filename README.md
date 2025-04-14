# SwiftTasksVision

**SwiftTasksVision** is a Swift package that facilitates the integration of Google's MediaPipe Vision solutions into your iOS applications. By adding this package as a dependency, you can seamlessly access MediaPipe's powerful vision APIs without the need for CocoaPods.

> **Disclaimer:** This project is an independent endeavor and is **not affiliated with Google**.

## Features

- **Swift Package Integration:** Simplify your project setup by integrating MediaPipe Vision through Swift Package Manager.
- **Example Application:** Includes an adapted version of Google's original example app, showcasing integration via Swift Package Manager instead of CocoaPods.
- **Automatic Package Update:** On a daily basis the package is updated by a GitHub Action (if needed) and tracks the MediaPipe Vision Task Pods versioning.

## Installation

To integrate **MediaPipeTasksVision** into your Xcode project using this package:

1. **Add Package Dependency:**
   - Open your project in Xcode.
   - Navigate to `File` > `Add Packages...`.
   - Enter the repository URL for SwiftTasksVision.
   - Select the desired version and add the package.

2. **Import and Use:**
   - In your Swift files, finally import MediaPipeTasksVision:
     ```swift
     import MediaPipeTasksVision
     ```
   - Utilize MediaPipe's Vision APIs as documented.

## Example Application

The package includes an adjusted example application (originally from Google) demonstrating real-time pose detection using MediaPipe Vision. This serves as a practical reference for integrating and utilizing the APIs in your projects.

## About MediaPipe Vision

[MediaPipe](https://ai.google.dev/edge/mediapipe/solutions/guide) is a cross-platform framework by Google that offers customizable machine learning solutions for live and streaming media. The Vision component provides state-of-the-art models and tools for tasks such as object detection, face detection, and more.

For detailed information and documentation, refer to the [MediaPipe Tasks Guide](https://ai.google.dev/edge/mediapipe/solutions/tasks).

## License

This project is licensed under the MIT License.

---

*Note: MediaPipe is a trademark of Google. This project is not affiliated with or endorsed by Google.*
