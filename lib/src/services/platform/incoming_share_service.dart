/// A file shared into the app from another application.
class IncomingSharedFile {
  const IncomingSharedFile({required this.path, this.mimeType});

  /// Absolute path of the staged copy owned by this app.
  final String path;

  final String? mimeType;
}

/// Boundary for receiving Android share intents and iOS share-extension
/// payloads, across both cold and warm starts.
abstract interface class IncomingShareService {
  /// Shares that launched the app (cold start). Emits at most once.
  Future<List<IncomingSharedFile>> takeInitialShares();

  /// Shares arriving while the app is running (warm start).
  Stream<List<IncomingSharedFile>> get incomingShares;
}
