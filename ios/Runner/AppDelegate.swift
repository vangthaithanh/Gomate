import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "GoMatePostVideo") {
      GoMatePostVideoExporter.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
private class GoMatePostVideoExporter {
  private static var active: AVAssetExportSession?
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gomate/post_video", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
      guard active == nil, let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, let start = args["startMs"] as? Int,
            let end = args["endMs"] as? Int, start >= 0, end > start, end - start <= 30000 else {
        result(FlutterError(code: "INVALID_RANGE", message: "Invalid video range", details: nil)); return
      }
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
        result(FlutterError(code: "EXPORT_FAILED", message: "Unsupported video", details: nil)); return
      }
      let output = FileManager.default.temporaryDirectory.appendingPathComponent("gomate_post_\(UUID().uuidString).mp4")
      export.outputURL = output
      export.outputFileType = .mp4
      export.shouldOptimizeForNetworkUse = true
      export.timeRange = CMTimeRange(start: CMTime(value: Int64(start), timescale: 1000), duration: CMTime(value: Int64(end-start), timescale: 1000))
      active = export
      export.exportAsynchronously {
        DispatchQueue.main.async {
          active = nil
          let duration = CMTimeGetSeconds(AVURLAsset(url: output).duration) * 1000
          if export.status == .completed && duration.isFinite && duration > 0 && duration <= 30000 {
            result(["path": output.path, "durationMs": Int(duration.rounded(.up))])
          } else {
            try? FileManager.default.removeItem(at: output)
            result(FlutterError(code: "EXPORT_FAILED", message: "Cannot export a valid clip under 30 seconds", details: nil))
          }
        }
      }
    }
  }
}
