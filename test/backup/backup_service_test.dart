import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/backup/backup_service.dart';
import 'package:meme_library/src/domain/library_query.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late BackupService service;
  late Directory work;

  setUp(() async {
    harness = await TestHarness.create();
    work = Directory(p.join(harness.root.path, 'backup_work'));
    service = BackupService(
      repository: harness.repository,
      mediaStore: harness.mediaStore,
      workDirectory: work,
    );
  });

  tearDown(() => harness.dispose());

  Future<Meme> seedMeme(int seed, {String? title, List<String>? tags}) async {
    var meme = await harnessImport(harness, seed: seed);
    if (title != null) {
      meme = await harness.repository.updateMetadata(
        meme.id,
        title: () => title,
      );
    }
    if (tags != null) {
      final resolved = [
        for (final name in tags) await harness.repository.ensureTag(name),
      ];
      meme = await harness.repository.setTags(meme.id, resolved);
    }
    return meme;
  }

  Future<Map<String, Object?>> readManifest(File zip) async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final entry = archive.find('manifest.json')!;
    return jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, Object?>;
  }

  /// Builds an arbitrary archive from in-memory entries.
  Future<File> buildArchive(
    Map<String, List<int>> entries, {
    String name = 'custom.zip',
  }) async {
    await work.create(recursive: true);
    final zip = File(p.join(work.path, name));
    final encoder = ZipFileEncoder();
    encoder.create(zip.path);
    for (final entry in entries.entries) {
      final temp = File(p.join(work.path, 'tmp-entry'));
      await temp.writeAsBytes(entry.value, flush: true);
      await encoder.addFile(temp, entry.key);
      await temp.delete();
    }
    await encoder.close();
    return zip;
  }

  group('export', () {
    test('contains manifest, originals, and thumbnails', () async {
      final a = await seedMeme(1, title: 'First', tags: ['fun']);
      final b = await seedMeme(2);

      final progress = <(int, int)>[];
      final zip = await service.exportArchive(
        onProgress: (done, total) => progress.add((done, total)),
      );

      final manifest = await readManifest(zip);
      expect(manifest['version'], BackupService.formatVersion);
      expect(manifest['memeCount'], 2);
      expect(progress.last, (2, 2));

      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      for (final meme in [a, b]) {
        expect(archive.find('media/${meme.relativePath}'), isNotNull);
        expect(archive.find('media/${meme.thumbnailPath}'), isNotNull);
      }

      final memes = (manifest['memes']! as List<Object?>)
          .map((raw) => Meme.fromJson(raw! as Map<String, Object?>))
          .toList();
      expect(memes.map((m) => m.sha256).toSet(), {a.sha256, b.sha256});
      final first = memes.singleWhere((m) => m.id == a.id);
      expect(first.title, 'First');
      expect(first.tags.single.name, 'fun');
    });

    test('fails cleanly when a media file is missing on disk', () async {
      final meme = await seedMeme(3);
      await harness.mediaStore.resolve(meme.relativePath).delete();

      await expectLater(
        service.exportArchive(),
        throwsA(
          isA<BackupException>().having(
            (e) => e.reason,
            'reason',
            BackupErrorReason.missingMedia,
          ),
        ),
      );
      // No half-written archive remains.
      final leftovers = work.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.zip'),
      );
      expect(leftovers, isEmpty);
    });
  });

  group('restore round trip', () {
    test('reproduces the library on a clean install', () async {
      await seedMeme(10, title: 'Keep me', tags: ['fun', 'classic']);
      await seedMeme(11);
      final zip = await service.exportArchive();
      final exported = await harness.repository.query(const LibraryQuery());

      // Simulate a clean install: wipe everything.
      await harness.repository.replaceAll(const []);
      await harness.repository.reconcile();
      expect(await harness.repository.memeCount(), 0);

      final summary = await service.restoreArchive(zip);
      expect(summary.memeCount, 2);
      expect(summary.tagCount, 2);

      final restored = await harness.repository.query(const LibraryQuery());
      expect(restored.items, exported.items);
      for (final meme in restored.items) {
        expect(
          await harness.mediaStore.exists(meme.relativePath),
          isTrue,
          reason: meme.relativePath,
        );
        expect(await harness.mediaStore.exists(meme.thumbnailPath), isTrue);
      }

      // Search works after restore.
      final hits = await harness.repository.query(
        const LibraryQuery(searchText: 'keep'),
      );
      expect(hits.items, hasLength(1));
    });

    test('replaces existing content and is idempotent', () async {
      await seedMeme(20, title: 'In backup');
      final zip = await service.exportArchive();

      await seedMeme(21, title: 'Added later');
      expect(await harness.repository.memeCount(), 2);

      final first = await service.restoreArchive(zip);
      expect(first.memeCount, 1);
      expect(await harness.repository.memeCount(), 1);

      final second = await service.restoreArchive(zip);
      expect(second.memeCount, 1);
      expect(await harness.repository.memeCount(), 1);
      final only = (await harness.repository.query(
        const LibraryQuery(),
      )).items.single;
      expect(only.title, 'In backup');
    });

    test('restores thumbnails even when absent from the archive', () async {
      final meme = await seedMeme(22);
      final zip = await service.exportArchive();

      // Strip the thumbnail from the archive.
      final original = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final entries = <String, List<int>>{};
      for (final file in original.files) {
        if (file.isFile && !file.name.startsWith('media/thumbs/')) {
          entries[file.name] = file.readBytes()!;
        }
      }
      final stripped = await buildArchive(entries, name: 'no-thumbs.zip');

      await service.restoreArchive(stripped);
      expect(await harness.mediaStore.exists(meme.thumbnailPath), isTrue);
    });
  });

  group('corrupt and incompatible archives', () {
    Matcher failsWith(BackupErrorReason reason) => throwsA(
      isA<BackupException>().having((e) => e.reason, 'reason', reason),
    );

    Future<void> expectLibraryUntouched(Meme survivor) async {
      expect(await harness.repository.memeCount(), 1);
      final current = await harness.repository.memeById(survivor.id);
      expect(current, isNotNull);
      expect(await harness.mediaStore.exists(survivor.relativePath), isTrue);
    }

    test('rejects a non-zip file', () async {
      final survivor = await seedMeme(30);
      await work.create(recursive: true);
      final bogus = File(p.join(work.path, 'bogus.zip'));
      await bogus.writeAsBytes(List.filled(128, 42));

      await expectLater(
        service.restoreArchive(bogus),
        failsWith(BackupErrorReason.unreadableArchive),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects a truncated archive', () async {
      final survivor = await seedMeme(31);
      final zip = await service.exportArchive();
      final bytes = await zip.readAsBytes();
      final truncated = File(p.join(work.path, 'truncated.zip'));
      await truncated.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

      await expectLater(
        service.restoreArchive(truncated),
        throwsA(isA<BackupException>()),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects an archive without a manifest', () async {
      final survivor = await seedMeme(32);
      final zip = await buildArchive({
        'media/originals/x.png': pngBytes(seed: 99),
      });

      await expectLater(
        service.restoreArchive(zip),
        failsWith(BackupErrorReason.malformedManifest),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects manifests with traversal or absolute media paths', () async {
      final survivor = await seedMeme(38);

      Future<void> expectRejected(String relativePath) async {
        final meme = (await harness.repository.query(
          const LibraryQuery(limit: 1),
        )).items.single;
        final json = meme.toJson()..['relativePath'] = relativePath;
        final zip = await buildArchive({
          'manifest.json': utf8.encode(
            jsonEncode({
              'version': 1,
              'memes': [json],
            }),
          ),
        }, name: 'slip.zip');

        await expectLater(
          service.restoreArchive(zip),
          failsWith(BackupErrorReason.malformedManifest),
          reason: relativePath,
        );
      }

      await expectRejected('../../escape.png');
      await expectRejected('originals/../../escape.png');
      await expectRejected('/etc/passwd');
      await expectRejected(r'C:\Windows\escape.png');
      await expectRejected('thumbs/wrong-root.png');
      await expectLibraryUntouched(survivor);
    });

    test('rejects a malformed manifest', () async {
      final survivor = await seedMeme(33);
      final zip = await buildArchive({
        'manifest.json': utf8.encode('this is not json'),
      });

      await expectLater(
        service.restoreArchive(zip),
        failsWith(BackupErrorReason.malformedManifest),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects a future archive version', () async {
      final survivor = await seedMeme(34);
      final zip = await buildArchive({
        'manifest.json': utf8.encode(
          jsonEncode({'version': 99, 'memes': <Object?>[]}),
        ),
      });

      await expectLater(
        service.restoreArchive(zip),
        failsWith(BackupErrorReason.unsupportedVersion),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects an archive with missing media', () async {
      final survivor = await seedMeme(35);
      final zip = await service.exportArchive();

      final original = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final entries = <String, List<int>>{
        for (final file in original.files)
          if (file.isFile && !file.name.startsWith('media/originals/'))
            file.name: file.readBytes()!,
      };
      final gutted = await buildArchive(entries, name: 'gutted.zip');

      await expectLater(
        service.restoreArchive(gutted),
        failsWith(BackupErrorReason.missingMedia),
      );
      await expectLibraryUntouched(survivor);
    });

    test('rejects tampered media (checksum mismatch)', () async {
      final survivor = await seedMeme(36);
      final zip = await service.exportArchive();

      final original = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final entries = <String, List<int>>{};
      for (final file in original.files) {
        if (!file.isFile) continue;
        entries[file.name] = file.name.startsWith('media/originals/')
            ? pngBytes(seed: 250) // different content, same manifest hash
            : file.readBytes()!;
      }
      final tampered = await buildArchive(entries, name: 'tampered.zip');

      await expectLater(
        service.restoreArchive(tampered),
        failsWith(BackupErrorReason.checksumMismatch),
      );
      await expectLibraryUntouched(survivor);
    });

    test('an interrupted restore leaves the library unchanged', () async {
      final survivor = await seedMeme(37, title: 'Still here');
      final other = await TestHarness.create();
      addTearDown(other.dispose);

      // Build a valid backup of a different library.
      await harnessImport(other, seed: 40);
      final otherService = BackupService(
        repository: other.repository,
        mediaStore: other.mediaStore,
        workDirectory: Directory(p.join(other.root.path, 'backup_work')),
      );
      final zip = await otherService.exportArchive();

      service.debugBeforeApply = () async {
        throw const FileSystemException('simulated crash');
      };
      await expectLater(service.restoreArchive(zip), throwsA(anything));

      await expectLibraryUntouched(survivor);
      expect(
        (await harness.repository.memeById(survivor.id))!.title,
        'Still here',
      );
      // Staging is cleaned up.
      final staged = work
          .listSync(recursive: false)
          .where((e) => p.basename(e.path).startsWith('restore-'));
      expect(staged, isEmpty);
    });
  });
}
