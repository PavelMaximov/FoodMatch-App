import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "foodmatch/session_share",
                                       binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "share" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: String],
            let text = args["text"], let rawURL = args["url"],
            let url = URL(string: rawURL), url.scheme == "foodmatch",
            let scene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "share_unavailable", message: "Cannot open share sheet", details: nil))
        return
      }
      var presenter = root
      while let presented = presenter.presentedViewController {
        presenter = presented
      }
      guard !(presenter is UIActivityViewController) else {
        result(FlutterError(code: "share_busy", message: "Share sheet already open", details: nil))
        return
      }
      let sheet = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                    y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      sheet.completionWithItemsHandler = { _, _, _, error in
        if error != nil {
          result(FlutterError(code: "share_failed", message: "Could not share invitation", details: nil))
        } else {
          result(nil)
        }
      }
      presenter.present(sheet, animated: true)
    }
  }
}
