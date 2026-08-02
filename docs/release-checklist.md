# Release Checklist

## Automated (every release tag)

Pushing a `vX.Y.Z` tag runs both workflows from a clean checkout:

- `CI` (format, analyze, tests, Android debug, iOS simulator) — also
  triggered by the tag itself.
- `Release`: a verify job re-runs format/analyze/tests and fails unless
  the tag matches `version:` in `pubspec.yaml`, then builds the APK,
  AAB, and unsigned IPA and publishes them on the GitHub release.
  Artifacts built without signing secrets are suffixed `-debugsigned`.

## Versioning

- [ ] `version:` bumped in `pubspec.yaml` (name+build, e.g. `1.0.1+2`)
      before tagging — the release verify job enforces the match.

## Signing

- [ ] Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` secrets configured for
      store-uploadable AABs. No keystore files in the repository.
- [ ] iOS: archive + sign in Xcode (or CI with certificates) before App
      Store submission; the published IPA artifact is unsigned by design.

## Manual device pass (physical devices, both platforms)

See `docs/manual-test-matrix.md` for the full matrix. Blockers:

- [ ] Clean install: import via clipboard, link, and share.
- [ ] Upgrade install from the previous release: library intact.
- [ ] Copy → paste into two messaging apps; share sheet works.
- [ ] Backup export, uninstall, reinstall, restore: library reproduced.
- [ ] VoiceOver / TalkBack pass on library, detail, and settings.

## Store metadata

- [ ] Listing describes local-only storage accurately (`docs/privacy.md`).
- [ ] Data safety / privacy label: no data collected.
- [ ] Screenshots up to date.
