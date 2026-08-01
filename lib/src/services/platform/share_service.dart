/// Boundary for the outbound native share sheet.
abstract interface class ShareService {
  /// Opens the platform share sheet for the file at [absolutePath].
  Future<void> shareFile(String absolutePath, {String? mimeType});
}
