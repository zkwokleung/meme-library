import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/import/url_import_service.dart';

import '../helpers/image_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late MediaStore media;
  late DriftLibraryRepository repo;
  late ImportCoordinator coordinator;
  late HttpServer server;

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('url_import_test');
    db = AppDatabase.inMemory();
    media = MediaStore(root);
    await media.init();
    repo = DriftLibraryRepository(db, media);
    coordinator = ImportCoordinator(
      repository: repo,
      mediaStore: media,
      pipeline: const InlineImagePipeline(),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    await root.delete(recursive: true);
  });

  void serve(void Function(HttpRequest request) handler) {
    server.listen(handler);
  }

  test('imports a valid image URL and records the source', () async {
    final image = pngBytes(seed: 1);
    serve((request) {
      request.response
        ..headers.contentType = ContentType('image', 'png')
        ..add(image);
      request.response.close();
    });

    final service = UrlImportService(coordinator);
    final outcome = await service.importFromUrl(url('/meme.png'));

    final success = outcome as ImportSuccess;
    expect(success.meme.sourceRef, url('/meme.png'));
    expect(await repo.memeCount(), 1);
  });

  test('follows redirects', () async {
    final image = pngBytes(seed: 2);
    serve((request) {
      if (request.uri.path == '/old') {
        request.response
          ..statusCode = HttpStatus.movedPermanently
          ..headers.set('location', url('/new'));
        request.response.close();
      } else {
        request.response.add(image);
        request.response.close();
      }
    });

    final outcome = await UrlImportService(
      coordinator,
    ).importFromUrl(url('/old'));
    expect(outcome, isA<ImportSuccess>());
  });

  test('rejects non-http schemes and malformed input', () async {
    final service = UrlImportService(coordinator);
    for (final bad in ['ftp://example.com/x.png', 'not a url', '']) {
      final outcome = await service.importFromUrl(bad);
      expect(outcome, isA<ImportFailure>(), reason: bad);
    }
    expect(await repo.memeCount(), 0);
  });

  test('non-200 responses fail with the status code', () async {
    serve((request) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    });

    final failure =
        await UrlImportService(coordinator).importFromUrl(url('/gone'))
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.network);
    expect(failure.message, contains('404'));
  });

  test('declared oversized responses are rejected before download', () async {
    serve((request) async {
      // Send only the headers; closing with a short body would abort the
      // connection on Linux before the client sees the content-length.
      request.response.headers.contentLength = 1024 * 1024;
      request.response.bufferOutput = false;
      request.response.add(List.filled(64, 0));
      try {
        await request.response.flush();
      } catch (_) {}
      // Never close; tearDown force-closes the server.
    });

    final failure =
        await UrlImportService(
              coordinator,
              maxResponseBytes: 1024,
            ).importFromUrl(url('/big'))
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.tooLarge);
    expect(await repo.memeCount(), 0);
  });

  test('chunked oversized responses are abandoned mid-stream', () async {
    serve((request) async {
      // No content-length; stream chunks forever until the client bails.
      request.response.bufferOutput = false;
      try {
        for (var i = 0; i < 1000; i++) {
          request.response.add(List.filled(1024, i % 256));
          await request.response.flush();
        }
      } catch (_) {
        // Client disconnected, expected.
      }
      try {
        await request.response.close();
      } catch (_) {}
    });

    final failure =
        await UrlImportService(
              coordinator,
              maxResponseBytes: 8 * 1024,
            ).importFromUrl(url('/stream'))
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.tooLarge);
    expect(await media.listManagedFiles(), isEmpty);
  });

  test('slow responses time out', () async {
    serve((request) {
      // Never respond.
    });

    final failure =
        await UrlImportService(
              coordinator,
              timeout: const Duration(milliseconds: 200),
            ).importFromUrl(url('/hang'))
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.network);
    expect(failure.message.toLowerCase(), contains('timed out'));
  });

  test('connection failures are reported as network errors', () async {
    final deadUrl = url('/dead');
    await server.close(force: true);
    final failure =
        await UrlImportService(coordinator).importFromUrl(deadUrl)
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.network);
  });

  test('non-image responses fail validation without partial records', () async {
    serve((request) {
      request.response.write('<html>not an image</html>');
      request.response.close();
    });

    final failure =
        await UrlImportService(coordinator).importFromUrl(url('/page'))
            as ImportFailure;
    expect(failure.reason, ImportFailureReason.unsupportedFormat);
    expect(await repo.memeCount(), 0);
    expect(await media.listManagedFiles(), isEmpty);
  });
}
