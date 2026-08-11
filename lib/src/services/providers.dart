import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/channel_platform_services.dart';
import 'platform/clipboard_service.dart';
import 'platform/gallery_picker.dart';
import 'platform/incoming_share_service.dart';
import 'platform/share_service.dart';
import 'platform/update_installer.dart';

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

/// Overridden per platform at startup: `PHPickerViewController` through the
/// method channel on iOS, the `image_picker` plugin on Android.
final galleryPickerProvider = Provider<GalleryPicker>(
  (ref) => throw UnimplementedError('galleryPickerProvider must be overridden'),
);

final heicTranscoderProvider = Provider<HeicTranscoder>(
  (ref) =>
      throw UnimplementedError('heicTranscoderProvider must be overridden'),
);

/// Needs no bootstrap wiring, so the real implementation is the default.
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => const ChannelUpdateInstaller(),
);
