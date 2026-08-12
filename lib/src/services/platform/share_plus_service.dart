import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

/// Outbound share sheet backed by the platform share UI.
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareFiles(List<ShareableFile> files) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final file in files)
            XFile(file.absolutePath, mimeType: file.mimeType),
        ],
      ),
    );
  }
}
