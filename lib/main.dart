import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/data/database/app_database.dart';
import 'src/data/library_repository.dart';
import 'src/data/media_store.dart';
import 'src/services/platform/channel_platform_services.dart';
import 'src/services/platform/gallery_picker.dart';
import 'src/services/platform/share_plus_service.dart';
import 'src/services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opt into the Android photo picker (ACTION_PICK_IMAGES). Without this
  // the plugin silently falls back to ACTION_GET_CONTENT: no error, no
  // failing test — only a manual check would ever catch it.
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }

  final documents = await getApplicationDocumentsDirectory();
  final dataDir = Directory(p.join(documents.path, 'meme_library'));
  await dataDir.create(recursive: true);

  final database = AppDatabase.file(dataDir);
  final mediaStore = MediaStore(Directory(p.join(dataDir.path, 'media')));
  await mediaStore.init();
  await mediaStore.clearStaging();
  final repository = DriftLibraryRepository(database, mediaStore);

  final temp = await getTemporaryDirectory();
  final backupWorkDir = Directory(p.join(temp.path, 'meme_library_backup'));
  // Exposed to the installer through the FileProvider "updates" cache-path.
  final updateWorkDir = Directory(p.join(temp.path, 'meme_library_updates'));

  runApp(
    ProviderScope(
      overrides: [
        backupWorkDirectoryProvider.overrideWithValue(backupWorkDir),
        updateWorkDirectoryProvider.overrideWithValue(updateWorkDir),
        mediaStoreProvider.overrideWithValue(mediaStore),
        libraryRepositoryProvider.overrideWithValue(repository),
        clipboardServiceProvider.overrideWithValue(
          const ChannelClipboardService(),
        ),
        shareServiceProvider.overrideWithValue(const SharePlusShareService()),
        incomingShareServiceProvider.overrideWithValue(
          ChannelIncomingShareService(),
        ),
        // iOS goes through PHPickerViewController on the method channel:
        // image_picker_ios re-encodes every result through UIImage, which
        // flattens APNG and animated WebP and re-times animated GIFs.
        // Android's plugin path is a byte-exact passthrough.
        galleryPickerProvider.overrideWithValue(
          Platform.isIOS
              ? const ChannelGalleryPicker()
              : const ImagePickerGalleryPicker(),
        ),
        heicTranscoderProvider.overrideWithValue(const ChannelHeicTranscoder()),
      ],
      child: const MemeLibraryApp(),
    ),
  );
}
