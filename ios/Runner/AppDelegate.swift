import Flutter
import UIKit
import UniformTypeIdentifiers

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlatformChannels") {
      PlatformChannels.register(with: registrar)
    }
  }
}

/// Native side of `com.zkwokleung.memelibrary/platform`.
///
/// Clipboard access uses `UIPasteboard`; incoming shares are drained from
/// the App Group inbox that the share extension writes into.
///
/// Defined in this file (instead of its own) so the class is always part
/// of the Runner target regardless of Xcode project migrations.
public class PlatformChannels: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let appGroupId = "group.com.zkwokleung.memelibrary"

  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlatformChannels()
    let channel = FlutterMethodChannel(
      name: "com.zkwokleung.memelibrary/platform",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)

    let events = FlutterEventChannel(
      name: "com.zkwokleung.memelibrary/incoming_shares",
      binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "clipboard.readImage":
      result(readClipboardImage())
    case "clipboard.writeImage":
      guard let args = call.arguments as? [String: Any],
            let bytes = args["bytes"] as? FlutterStandardTypedData else {
        result(false)
        return
      }
      result(writeClipboardImage(data: bytes.data))
    case "shares.takeInitial":
      result(Self.drainShareInbox())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Clipboard

  private func readClipboardImage() -> [String: Any?]? {
    let pasteboard = UIPasteboard.general
    for type in [UTType.png.identifier, UTType.jpeg.identifier, UTType.webP.identifier] {
      if let data = pasteboard.data(forPasteboardType: type), !data.isEmpty {
        return ["bytes": FlutterStandardTypedData(bytes: data), "name": nil]
      }
    }
    // Fall back to any renderable image (e.g. copied from Photos).
    if let image = pasteboard.image, let data = image.pngData() {
      return ["bytes": FlutterStandardTypedData(bytes: data), "name": nil]
    }
    return nil
  }

  private func writeClipboardImage(data: Data) -> Bool {
    let type: String
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
      type = UTType.png.identifier
    } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
      type = UTType.jpeg.identifier
    } else if data.count > 12, data[8...11].elementsEqual("WEBP".utf8) {
      // WebP pastes poorly across apps; convert to PNG for compatibility.
      guard let image = UIImage(data: data), let png = image.pngData() else { return false }
      UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
      return true
    } else {
      return false
    }
    UIPasteboard.general.setData(data, forPasteboardType: type)
    return true
  }

  // MARK: - Incoming shares

  /// Moves every file the share extension staged in the App Group inbox
  /// into this app's temporary directory and returns the new paths.
  static func drainShareInbox() -> [[String: Any?]] {
    let fileManager = FileManager.default
    guard let container = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId) else {
      return []
    }
    let inbox = container.appendingPathComponent("inbox", isDirectory: true)
    guard let entries = try? fileManager.contentsOfDirectory(
      at: inbox, includingPropertiesForKeys: nil) else {
      return []
    }

    var shares: [[String: Any?]] = []
    for entry in entries {
      let target = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
      do {
        try fileManager.moveItem(at: entry, to: target)
        shares.append(["path": target.path, "mimeType": nil])
      } catch {
        try? fileManager.removeItem(at: entry)
      }
    }
    return shares
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?,
                       eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    // A re-subscribe (hot restart) must not leak the previous observer.
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      let shares = Self.drainShareInbox()
      if !shares.isEmpty {
        self?.eventSink?(shares)
      }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }
}
