import Flutter
import ImageIO
import Photos
import PhotosUI
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

  /// Mirrors ImageValidator.defaultMaxFileSizeBytes on the Dart side.
  static let maxImportBytes = 25 * 1024 * 1024

  /// Mirrors ImageValidator.defaultMaxPixels on the Dart side.
  static let maxImportPixels = 50_000_000

  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private var pickerDelegate: GalleryPickerDelegate?

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
    case "app.getVersion":
      result(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    case "system.openUrl":
      guard let args = call.arguments as? [String: Any],
            let raw = args["url"] as? String,
            let url = URL(string: raw), url.scheme == "https" else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { ok in result(ok) }
    case "gallery.pickImages":
      presentGalleryPicker(result: result)
    case "image.transcodeToJpeg":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(nil)
        return
      }
      // Decoding a 50 MP image is not main-thread work.
      DispatchQueue.global(qos: .userInitiated).async {
        let payload = Self.transcodeToJpeg(path: path)
        DispatchQueue.main.async { result(payload) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Gallery picker

  /// Presents `PHPickerViewController` and returns `[{path, name}]`, or an
  /// empty list when the user cancels.
  ///
  /// PHPicker runs out of process, so this needs no photo-library
  /// permission and shows no authorization prompt. `.current` asset
  /// representation plus `loadDataRepresentation` hands back the original
  /// file bytes — animated GIF, animated WebP, and APNG all survive, which
  /// a `UIImage` round trip would destroy.
  private func presentGalleryPicker(result: @escaping FlutterResult) {
    // FlutterResult takes Any?, which gives a bare `[]` literal no type to
    // infer from; spell the element type out.
    let noSelection = [[String: Any?]]()
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
      .first?.rootViewController else {
      result(noSelection)
      return
    }
    if pickerDelegate != nil {
      // A picker is already on screen; a second request would leak the
      // first delegate and strand its Flutter result.
      result(noSelection)
      return
    }

    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.filter = .images
    config.selectionLimit = 0
    config.preferredAssetRepresentationMode = .current

    let controller = PHPickerViewController(configuration: config)
    let delegate = GalleryPickerDelegate { [weak self] picked in
      self?.pickerDelegate = nil
      result(picked)
    }
    pickerDelegate = delegate
    controller.delegate = delegate
    root.present(controller, animated: true)
  }

  // MARK: - HEIC transcode

  /// Re-encodes a HEIF-family image at [path] as JPEG, or returns nil when
  /// it is not HEIF or would breach the import limits.
  ///
  /// The rotation is baked into the pixels rather than written as an
  /// orientation tag, so the JPEG that reaches Dart needs no special
  /// handling and hashes the same however the source expressed rotation.
  static func transcodeToJpeg(path: String) -> [String: Any?]? {
    let url = URL(fileURLWithPath: path)
    guard let size = (try? FileManager.default
      .attributesOfItem(atPath: path)[.size]) as? Int,
      size > 0, size <= maxImportBytes else {
      return nil
    }

    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
          CGImageSourceGetCount(source) > 0,
          let uti = CGImageSourceGetType(source) as String?,
          let sourceType = UTType(uti),
          sourceType.conforms(to: .heic) || sourceType.conforms(to: .heif) else {
      return nil
    }

    // Header-only pixel check before allocating anything: a small HEIC can
    // declare an enormous canvas.
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
    let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
    guard width > 0, height > 0, width * height <= maxImportPixels else {
      return nil
    }

    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
          let image = UIImage(data: data) else {
      return nil
    }

    // UIImage carries the container's orientation; rendering it once
    // yields upright pixels.
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let upright = UIGraphicsImageRenderer(size: image.size, format: format)
      .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }

    // Quality 1.0 on a 12 MP photo routinely exceeds the source HEIC
    // several times over and can breach the import cap.
    guard let jpeg = upright.jpegData(compressionQuality: 0.92),
          !jpeg.isEmpty, jpeg.count <= maxImportBytes else {
      return nil
    }
    return ["bytes": FlutterStandardTypedData(bytes: jpeg)]
  }

  // MARK: - Clipboard

  private func readClipboardImage() -> [String: Any?]? {
    let pasteboard = UIPasteboard.general
    // GIF must be checked before the pasteboard.image fallback, which
    // would flatten an animation into a static PNG.
    for type in [
      UTType.gif.identifier, UTType.png.identifier,
      UTType.jpeg.identifier, UTType.webP.identifier,
    ] {
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
    } else if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
      // GIF89a/87a: set the raw bytes so the animation survives the paste.
      type = UTType.gif.identifier
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

/// Copies each picked asset's original bytes into the temporary directory
/// and reports the staged paths.
///
/// Held as a strong reference by `PlatformChannels` for the lifetime of
/// one presentation: `PHPickerViewController.delegate` is weak, and the
/// Flutter result must be delivered exactly once.
private final class GalleryPickerDelegate: NSObject, PHPickerViewControllerDelegate {
  init(completion: @escaping ([[String: Any?]]) -> Void) {
    self.completion = completion
  }

  private let completion: ([[String: Any?]]) -> Void
  private var finished = false

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard !finished else { return }
    finished = true

    if results.isEmpty {
      completion([])
      return
    }

    // Results load concurrently but must be reported in the order the user
    // picked them, so collect into a fixed-size slot array.
    var staged = [[String: Any?]?](repeating: nil, count: results.count)
    let group = DispatchGroup()
    let lock = NSLock()

    for (index, result) in results.enumerated() {
      group.enter()
      let name = result.itemProvider.suggestedName
      result.itemProvider.loadDataRepresentation(
        forTypeIdentifier: UTType.image.identifier
      ) { data, _ in
        defer { group.leave() }
        guard let data, !data.isEmpty,
              data.count <= PlatformChannels.maxImportBytes else {
          return
        }
        let target = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent(UUID().uuidString)
        guard (try? data.write(to: target, options: .atomic)) != nil else { return }
        lock.lock()
        staged[index] = ["path": target.path, "name": name]
        lock.unlock()
      }
    }

    group.notify(queue: .main) { [completion] in
      completion(staged.compactMap { $0 })
    }
  }
}
