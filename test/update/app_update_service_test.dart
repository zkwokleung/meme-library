import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/update/app_update_service.dart';

void main() {
  group('SemVer', () {
    test('parses plain, v-prefixed, and build-suffixed versions', () {
      expect(SemVer.tryParse('1.2.3'), const SemVer(1, 2, 3));
      expect(SemVer.tryParse('v1.2.3'), const SemVer(1, 2, 3));
      expect(SemVer.tryParse('1.2.3+4'), const SemVer(1, 2, 3));
      expect(SemVer.tryParse('v10.0.99+12'), const SemVer(10, 0, 99));
    });

    test('rejects malformed versions', () {
      for (final bad in ['', '1.2', '1.2.3.4', '1.2.x', 'abc', '1. 2.3']) {
        expect(SemVer.tryParse(bad), isNull, reason: bad);
      }
    });

    test('compares numerically, not lexically', () {
      expect(
        const SemVer(1, 0, 10).compareTo(const SemVer(1, 0, 9)),
        greaterThan(0),
      );
      expect(
        const SemVer(2, 0, 0).compareTo(const SemVer(1, 9, 9)),
        greaterThan(0),
      );
      expect(
        const SemVer(1, 1, 0).compareTo(const SemVer(1, 2, 0)),
        lessThan(0),
      );
      expect(const SemVer(1, 2, 3).compareTo(const SemVer(1, 2, 3)), 0);
    });
  });

  group('AppUpdateService', () {
    late Directory root;
    late Directory workDir;
    late HttpServer server;

    String url(String path) => 'http://127.0.0.1:${server.port}$path';

    AppUpdateService service({int? maxApkBytes, Duration? timeout}) =>
        AppUpdateService(
          workDirectory: workDir,
          latestReleaseUri: Uri.parse(url('/latest')),
          maxApkBytes: maxApkBytes ?? AppUpdateService.defaultMaxApkBytes,
          timeout: timeout ?? const Duration(seconds: 5),
        );

    setUp(() async {
      root = await Directory.systemTemp.createTemp('app_update_test');
      workDir = Directory('${root.path}/updates');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    void serve(void Function(HttpRequest request) handler) {
      server.listen(handler);
    }

    Map<String, Object?> releaseJson({
      String tag = 'v1.1.0',
      Object? assets,
      String? notes = 'Release notes',
    }) => {
      'tag_name': tag,
      'html_url':
          'https://github.com/zkwokleung/meme-library/releases/tag/$tag',
      'body': notes,
      'assets':
          assets ??
          [
            {
              'name': 'meme-library-$tag.apk',
              'browser_download_url': url('/download/$tag.apk'),
              'size': 1234,
            },
          ],
    };

    void serveRelease(Map<String, Object?> release) {
      serve((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(release));
        request.response.close();
      });
    }

    UpdateInfo apkInfo(String path, {int? size, String tag = 'v1.1.0'}) =>
        UpdateInfo(
          latestVersion: const SemVer(1, 1, 0),
          tagName: tag,
          releasePageUrl: 'https://example.com/release',
          apkDownloadUrl: url(path),
          apkSizeBytes: size,
        );

    group('checkForUpdate', () {
      test('reports a newer release with its apk asset', () async {
        serveRelease(releaseJson());

        final check = await service().checkForUpdate('1.0.0');

        final available = check as UpdateAvailable;
        expect(available.info.latestVersion, const SemVer(1, 1, 0));
        expect(available.info.tagName, 'v1.1.0');
        expect(available.info.apkDownloadUrl, url('/download/v1.1.0.apk'));
        expect(available.info.apkSizeBytes, 1234);
        expect(available.info.releaseNotes, 'Release notes');
      });

      test('sends the GitHub API headers', () async {
        String? userAgent;
        String? accept;
        serve((request) {
          userAgent = request.headers.value('user-agent');
          accept = request.headers.value('accept');
          request.response.write(jsonEncode(releaseJson()));
          request.response.close();
        });

        await service().checkForUpdate('1.0.0');

        expect(userAgent, 'meme-library-app');
        expect(accept, 'application/vnd.github+json');
      });

      test('same or newer installed version is up to date', () async {
        serveRelease(releaseJson(tag: 'v1.1.0'));

        expect(await service().checkForUpdate('1.1.0'), isA<UpToDate>());
        expect(await service().checkForUpdate('1.2.0'), isA<UpToDate>());
        expect(await service().checkForUpdate('1.1.0+5'), isA<UpToDate>());
      });

      test('picks the first apk among mixed assets', () async {
        serveRelease(
          releaseJson(
            assets: [
              {
                'name': 'meme-library-v1.1.0.aab',
                'browser_download_url': url('/download/v1.1.0.aab'),
                'size': 1,
              },
              {
                'name': 'meme-library-v1.1.0-unsigned.ipa',
                'browser_download_url': url('/download/v1.1.0.ipa'),
                'size': 2,
              },
              {
                'name': 'meme-library-v1.1.0-debugsigned.apk',
                'browser_download_url': url('/download/v1.1.0.apk'),
                'size': 3,
              },
            ],
          ),
        );

        final check = await service().checkForUpdate('1.0.0');

        final available = check as UpdateAvailable;
        expect(available.info.apkDownloadUrl, url('/download/v1.1.0.apk'));
        expect(available.info.apkSizeBytes, 3);
      });

      test(
        'a release without an apk asset reports a null download URL',
        () async {
          serveRelease(releaseJson(assets: <Object?>[]));

          final check = await service().checkForUpdate('1.0.0');

          expect((check as UpdateAvailable).info.apkDownloadUrl, isNull);
        },
      );

      test('404 means no releases', () async {
        serve((request) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        });

        await expectLater(
          service().checkForUpdate('1.0.0'),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('No releases'),
            ),
          ),
        );
      });

      test('403 maps to a rate-limit message', () async {
        serve((request) {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.close();
        });

        await expectLater(
          service().checkForUpdate('1.0.0'),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('rate limit'),
            ),
          ),
        );
      });

      test('malformed JSON and unparseable tags fail cleanly', () async {
        var call = 0;
        serve((request) {
          request.response.write(
            call++ == 0 ? 'not json' : jsonEncode(releaseJson(tag: 'nightly')),
          );
          request.response.close();
        });

        for (var i = 0; i < 2; i++) {
          await expectLater(
            service().checkForUpdate('1.0.0'),
            throwsA(
              isA<UpdateException>().having(
                (e) => e.message,
                'message',
                contains('release information'),
              ),
            ),
          );
        }
      });

      test('connection failures surface as an update exception', () async {
        final dead = service();
        await server.close(force: true);

        await expectLater(
          dead.checkForUpdate('1.0.0'),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('connection'),
            ),
          ),
        );
      });

      test('a malformed installed version fails before any request', () async {
        await expectLater(
          service().checkForUpdate('garbage'),
          throwsA(isA<UpdateException>()),
        );
      });
    });

    group('downloadApk', () {
      test('streams the apk to disk and removes the part file', () async {
        final bytes = List<int>.generate(64 * 1024, (i) => i % 256);
        serve((request) {
          request.response
            ..headers.contentLength = bytes.length
            ..add(bytes);
          request.response.close();
        });

        final file = await service().downloadApk(apkInfo('/app.apk'));

        expect(file.path, endsWith('v1.1.0.apk'));
        expect(await file.readAsBytes(), bytes);
        final leftovers = await workDir
            .list()
            .where((e) => e.path.endsWith('.part'))
            .toList();
        expect(leftovers, isEmpty);
      });

      test('reports monotonic progress up to the declared total', () async {
        final bytes = List<int>.filled(32 * 1024, 7);
        serve((request) {
          request.response
            ..headers.contentLength = bytes.length
            ..add(bytes);
          request.response.close();
        });

        final received = <int>[];
        int? total;
        await service().downloadApk(
          apkInfo('/app.apk'),
          onProgress: (r, t) {
            received.add(r);
            total = t;
          },
        );

        expect(received, isNotEmpty);
        for (var i = 1; i < received.length; i++) {
          expect(received[i], greaterThanOrEqualTo(received[i - 1]));
        }
        expect(received.last, bytes.length);
        expect(total, bytes.length);
      });

      test('a declared oversized apk is rejected before download', () async {
        serve((request) async {
          request.response.headers.contentLength = 1024 * 1024;
          request.response.bufferOutput = false;
          request.response.add(List.filled(64, 0));
          try {
            await request.response.flush();
          } catch (_) {}
          // Never close; tearDown force-closes the server.
        });

        await expectLater(
          service(maxApkBytes: 1024).downloadApk(apkInfo('/big.apk')),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('too large'),
            ),
          ),
        );
        expect(await workDir.list().toList(), isEmpty);
      });

      test('an oversized chunked download is abandoned mid-stream', () async {
        serve((request) async {
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

        await expectLater(
          service(maxApkBytes: 8 * 1024).downloadApk(apkInfo('/stream.apk')),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('too large'),
            ),
          ),
        );
        expect(await workDir.list().toList(), isEmpty);
      });

      test('a truncated download fails and leaves no file', () async {
        serve((request) async {
          request.response.headers.contentLength = 4096;
          request.response.bufferOutput = false;
          request.response.add(List.filled(1024, 1));
          try {
            await request.response.flush();
          } catch (_) {}
          try {
            // Closing below the declared contentLength aborts the connection.
            await request.response.close();
          } catch (_) {}
        });

        await expectLater(
          service().downloadApk(apkInfo('/cut.apk')),
          throwsA(isA<UpdateException>()),
        );
        expect(await workDir.list().toList(), isEmpty);
      });

      test('stalled downloads time out', () async {
        serve((request) async {
          request.response.headers.contentLength = 4096;
          request.response.bufferOutput = false;
          request.response.add(List.filled(64, 0));
          try {
            await request.response.flush();
          } catch (_) {}
          // Never send the rest.
        });

        await expectLater(
          service(
            timeout: const Duration(milliseconds: 200),
          ).downloadApk(apkInfo('/hang.apk')),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
      });

      test(
        'reuses a completed download without touching the network',
        () async {
          final bytes = List<int>.filled(2048, 5);
          var requests = 0;
          serve((request) {
            requests++;
            request.response
              ..headers.contentLength = bytes.length
              ..add(bytes);
            request.response.close();
          });
          final info = apkInfo('/app.apk', size: bytes.length);

          final first = await service().downloadApk(info);
          expect(requests, 1);

          final progress = <int>[];
          final second = await service().downloadApk(
            info,
            onProgress: (r, t) => progress.add(r),
          );

          expect(requests, 1);
          expect(second.path, first.path);
          expect(await second.readAsBytes(), bytes);
          expect(progress, [bytes.length]);
        },
      );

      test('a size-mismatched leftover is downloaded again', () async {
        final bytes = List<int>.filled(2048, 5);
        var requests = 0;
        serve((request) {
          requests++;
          request.response
            ..headers.contentLength = bytes.length
            ..add(bytes);
          request.response.close();
        });
        await workDir.create(recursive: true);
        await File(
          '${workDir.path}/v1.1.0.apk',
        ).writeAsBytes(List.filled(10, 0));

        final file = await service().downloadApk(
          apkInfo('/app.apk', size: bytes.length),
        );

        expect(requests, 1);
        expect(await file.readAsBytes(), bytes);
      });

      test('sweeps stale files from earlier attempts', () async {
        await workDir.create(recursive: true);
        final stale = File('${workDir.path}/v1.0.5.apk');
        await stale.writeAsBytes([1, 2, 3]);
        final bytes = List<int>.filled(1024, 9);
        serve((request) {
          request.response
            ..headers.contentLength = bytes.length
            ..add(bytes);
          request.response.close();
        });

        await service().downloadApk(apkInfo('/app.apk'));

        expect(await stale.exists(), isFalse);
      });

      test('a release without an apk url cannot be downloaded', () async {
        const info = UpdateInfo(
          latestVersion: SemVer(1, 1, 0),
          tagName: 'v1.1.0',
          releasePageUrl: 'https://example.com/release',
        );

        await expectLater(
          service().downloadApk(info),
          throwsA(isA<UpdateException>()),
        );
      });
    });
  });
}
