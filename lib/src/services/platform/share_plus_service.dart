import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

/// Outbound share sheet backed by the platform share UI.
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareFile(String absolutePath, {String? mimeType}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(absolutePath, mimeType: mimeType)]),
    );
  }
}
