enum InstallApkResult {
  /// The system installer was launched; it takes over from here.
  started,

  /// The user was sent to the "Install unknown apps" settings screen and
  /// must retry once the permission is granted.
  permissionRequested,

  failed,
}

/// Platform plumbing for the in-app update flow.
abstract interface class UpdateInstaller {
  /// The installed app version (`X.Y.Z`), or null when unavailable.
  Future<String?> installedVersion();

  /// Launches the package installer for a downloaded APK. Android only;
  /// other platforms report [InstallApkResult.failed].
  Future<InstallApkResult> installApk(String path);

  /// Opens an https URL in the system browser; other schemes are refused.
  Future<bool> openUrl(String url);
}
