# iOS Share Extension Setup

Receiving images shared from other iOS apps requires a Share Extension
target, which must be added once in Xcode (extension targets cannot be
created from the command line).

The Flutter app side is already implemented: on launch and on every
foreground activation it drains `inbox/` inside the App Group container
and imports whatever the extension staged there
(`ios/Runner/AppDelegate.swift`).

## One-time setup in Xcode

1. Open `ios/Runner.xcworkspace`.
2. **File → New → Target… → Share Extension**, name it `ShareInbox`,
   language Swift, no storyboard needed beyond the default.
3. Set the extension's bundle ID to
   `com.zkwokleung.memelibrary.ShareInbox` and its deployment target to
   iOS 18.0.
4. Add the **App Groups** capability to *both* the `Runner` and
   `ShareInbox` targets with the group id:
   `group.com.zkwokleung.memelibrary`
5. Restrict the extension to images in `ShareInbox/Info.plist`:

   ```xml
   <key>NSExtension</key>
   <dict>
     <key>NSExtensionAttributes</key>
     <dict>
       <key>NSExtensionActivationRule</key>
       <dict>
         <key>NSExtensionActivationSupportsImageWithMaxCount</key>
         <integer>10</integer>
       </dict>
     </dict>
     <key>NSExtensionMainStoryboard</key>
     <string>MainInterface</string>
     <key>NSExtensionPointIdentifier</key>
     <string>com.apple.share-services</string>
   </dict>
   ```

6. Replace the generated `ShareViewController.swift` with:

   ```swift
   import UIKit
   import Social
   import UniformTypeIdentifiers

   class ShareViewController: SLComposeServiceViewController {
     private let appGroupId = "group.com.zkwokleung.memelibrary"

     override func isContentValid() -> Bool { true }

     override func didSelectPost() {
       guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
         return complete()
       }
       let attachments = items.flatMap { $0.attachments ?? [] }
         .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
       let group = DispatchGroup()
       for attachment in attachments {
         group.enter()
         attachment.loadFileRepresentation(
           forTypeIdentifier: UTType.image.identifier
         ) { url, _ in
           defer { group.leave() }
           guard let url,
                 let container = FileManager.default.containerURL(
                   forSecurityApplicationGroupIdentifier: self.appGroupId)
           else { return }
           let inbox = container.appendingPathComponent("inbox", isDirectory: true)
           try? FileManager.default.createDirectory(
             at: inbox, withIntermediateDirectories: true)
           let target = inbox.appendingPathComponent(
             UUID().uuidString + "-" + url.lastPathComponent)
           try? FileManager.default.copyItem(at: url, to: target)
         }
       }
       group.notify(queue: .main) { self.complete() }
     }

     private func complete() {
       extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
     }

     override func configurationItems() -> [Any]! { [] }
   }
   ```

7. Build and run on a device, share an image from Photos or Safari, and
   confirm it appears in the library when the app opens.

## Verification checklist (physical device)

- Cold start: share an image while the app is closed → open the app →
  the image is imported.
- Warm start: share while the app is backgrounded → foreground it →
  the image is imported without a restart.
- Multiple images shared at once all import; duplicates resolve to the
  existing item.
