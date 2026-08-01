import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/clipboard_service.dart';
import 'platform/incoming_share_service.dart';
import 'platform/share_service.dart';

/// Providers for platform service boundaries.
///
/// Defaults throw so that missing wiring fails loudly; production
/// implementations override these at app startup and tests override them
/// with fakes via [ProviderScope.overrides].
final clipboardServiceProvider = Provider<ClipboardService>(
  (ref) =>
      throw UnimplementedError('clipboardServiceProvider must be overridden'),
);

final shareServiceProvider = Provider<ShareService>(
  (ref) => throw UnimplementedError('shareServiceProvider must be overridden'),
);

final incomingShareServiceProvider = Provider<IncomingShareService>(
  (ref) => throw UnimplementedError(
    'incomingShareServiceProvider must be overridden',
  ),
);
