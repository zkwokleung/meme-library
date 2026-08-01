# Release Checklist

## Automated (every release tag)

CI (`release.yml`) builds from a clean checkout:

- [ ] `CI` workflow green on the tagged commit (format, analyze, tests,
      Android debug, iOS simulator).
- [ ] Tag `vX.Y.Z` pushed; `Release` workflow produced the APK, AAB, and
      unsigned IPA on the GitHub release.

## Versioning

- [ ] `version:` bumped in `pubspec.yaml` (name+build, e.g. `1.0.0+2`).
- [ ] Tag matches the pubspec version.

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
