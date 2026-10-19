import Flutter
import UIKit
import UserNotifications
import Vision
// Needed for FlutterLocalNotificationsPlugin.setPluginRegistrantCallback.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Show dose reminders even while the app is open.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Lets the Yes / Skipped / Stopped buttons run when the app is in the background.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LabelTextRecognizer") {
      LabelTextRecognizer.register(with: registrar.messenger())
    }
  }
}

/// On-device label reading with Apple's Vision framework, exposed to Dart on
/// the "medstock/ocr" channel (Android uses ML Kit; see MainActivity.kt).
/// Returns lines top to bottom as [{text, height}], height being relative
/// size, used to guess the brand name (the biggest text on a pack).
enum LabelTextRecognizer {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "medstock/ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "args", message: "path is required", details: nil))
        return
      }
      recognize(path: path, result: result)
    }
  }

  private static func recognize(path: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      result(FlutterError(code: "image", message: "Can't open the image", details: nil))
      return
    }
    let request = VNRecognizeTextRequest { request, error in
      if let error {
        DispatchQueue.main.async { result(FlutterError(code: "ocr", message: error.localizedDescription, details: nil)) }
        return
      }
      let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
      // Vision's origin is bottom-left: sort top to bottom, then left to right.
      let lines: [[String: Any]] = observations
        .sorted { a, b in
          abs(a.boundingBox.maxY - b.boundingBox.maxY) > 0.01
            ? a.boundingBox.maxY > b.boundingBox.maxY
            : a.boundingBox.minX < b.boundingBox.minX
        }
        .compactMap { observation in
          guard let best = observation.topCandidates(1).first else { return nil }
          return ["text": best.string, "height": Double(observation.boundingBox.height * 1000)]
        }
      DispatchQueue.main.async { result(lines) }
    }
    request.recognitionLevel = .accurate
    // Brand and drug names aren't dictionary words; correction would "fix" them.
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "ocr", message: error.localizedDescription, details: nil)) }
      }
    }
  }
}

private extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
