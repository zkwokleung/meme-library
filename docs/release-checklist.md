# Release Checklist

## Automated (every release tag)

Pushing a `vX.Y.Z` tag runs both workflows from a clean checkout:

- `CI` (format, analyze, tests, Android debug, iOS simulator) — also
  triggered by the tag itself.
- `Release`: a verify job re-runs format/analyze/tests, validates the
  tag (`vMAJOR.MINOR.PATCH`, minor/patch ≤ 99) and checks the derived
  `versionCode` (`major*10000 + minor*100 + patch`) exceeds the
  previous release's, then builds the APK, AAB, and unsigned IPA with
  the version stamped from the tag and publishes them on the GitHub
  release. Artifacts built without signing secrets are suffixed
  `-debugsigned`.
- The in-app updater reads the **latest** GitHub release and picks the
  first `.apk` asset, so every release must attach exactly one APK.

## Versioning

- [ ] Releasing is just pushing a `vMAJOR.MINOR.PATCH` tag (minor and
      patch ≤ 99); the workflow stamps the version and a monotonic
      `versionCode` from it. Do **not** edit `version:` in
      `pubspec.yaml` — it is a dev-only placeholder. Local builds show
      `0.0.1` and the in-app updater routes them to the release page
      instead of installing (a dev build's signing key would reject the
      release APK anyway).

## Signing

- [ ] Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` secrets configured for
      store-uploadable AABs. No keystore files in the repository.
      The in-app updater also depends on this: Android refuses to install
      an APK signed with a different key than the installed build (the
      installer shows a generic "App not installed"), so a `-debugsigned`
      release cannot update a store-signed install or vice versa — users
      would have to uninstall first. Keep every release on the same key.
- [ ] iOS: archive + sign in Xcode (or CI with certificates) before App
      Store submission; the published IPA artifact is unsigned by design.

## Manual device pass (physical devices, both platforms)

See `docs/manual-test-matrix.md` for the full matrix. Blockers:

- [ ] Clean install: import via photos, clipboard, link, and share.
- [ ] First photo pick raises **no permission prompt** on either platform.
- [ ] Upgrade install from the previous release: library intact.
- [ ] On a build of the previous release, Settings → "Check for updates"
      finds this release, downloads it, and hands off to the installer
      (first run detours through the "Install unknown apps" toggle).
      On iOS it opens the release page in the browser.
- [ ] Copy → paste into two messaging apps; share sheet works.
- [ ] Backup export, uninstall, reinstall, restore: library reproduced.
- [ ] VoiceOver / TalkBack pass on library, detail, and settings.

## Store metadata

- [ ] Listing describes local-only storage accurately (`docs/privacy.md`).
- [ ] Data safety / privacy label: no data collected.
- [ ] Merged Android manifest declares no permission beyond `INTERNET`,
      `REQUEST_INSTALL_PACKAGES` (the in-app updater's installer handoff),
      and androidx's app-scoped `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
      — CI asserts this, but confirm before a store upload since plugin
      updates can merge in new permissions silently. In particular the
      photo picker must never pull in `READ_MEDIA_IMAGES`.
- [ ] Google Play restricts `REQUEST_INSTALL_PACKAGES`: fine for GitHub
      sideload distribution, but drop the in-app installer (or gate it
      out of the Play build) before any Play submission.
- [ ] `NSPhotoLibraryUsageDescription` present and honest (PHPicker never
      triggers it, but App Review expects the key).
- [ ] Screenshots up to date.
