import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/data/database/app_database.dart';
import 'src/data/library_repository.dart';
import 'src/data/media_store.dart';
import 'src/services/platform/channel_platform_services.dart';
import 'src/services/platform/share_plus_service.dart';
import 'src/services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ProviderScope(
      overrides: [
        backupWorkDirectoryProvider.overrideWithValue(backupWorkDir),
        mediaStoreProvider.overrideWithValue(mediaStore),
        libraryRepositoryProvider.overrideWithValue(repository),
        clipboardServiceProvider.overrideWithValue(
          const ChannelClipboardService(),
        ),
        shareServiceProvider.overrideWithValue(const SharePlusShareService()),
        incomingShareServiceProvider.overrideWithValue(
          ChannelIncomingShareService(),
        ),
      ],
      child: const MemeLibraryApp(),
    ),
  );
}
