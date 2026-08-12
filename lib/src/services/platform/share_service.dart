/// A file handed to the outbound share sheet.
class ShareableFile {
  const ShareableFile(this.absolutePath, {this.mimeType});

  final String absolutePath;
  final String? mimeType;
}

/// Boundary for the outbound native share sheet.
abstract interface class ShareService {
  /// Opens the platform share sheet for multiple files.
  Future<void> shareFiles(List<ShareableFile> files);
}

extension ShareSingleFile on ShareService {
  /// Opens the platform share sheet for the file at [absolutePath].
  Future<void> shareFile(String absolutePath, {String? mimeType}) =>
      shareFiles([ShareableFile(absolutePath, mimeType: mimeType)]);
}
