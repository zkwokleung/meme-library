import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../net/capped_http.dart';

/// pubspec.yaml's placeholder `version:`, mirrored: only the release
/// workflow stamps a real tag-derived version, so a build reporting this
/// is not an installable target for the updater.
const devPlaceholderVersionName = '0.0.1';

/// A `major.minor.patch` version. Release tags carry no build number, so
/// build metadata (`+N`) is ignored when comparing.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Accepts `1.2.3`, `v1.2.3`, and `1.2.3+4`; returns null when malformed.
  static SemVer? tryParse(String raw) {
    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }
    final plus = text.indexOf('+');
    if (plus != -1) {
      text = text.substring(0, plus);
    }
    final parts = text.split('.');
    if (parts.length != 3) return null;
    final numbers = <int>[];
    for (final part in parts) {
      if (part.isEmpty || part.trim() != part) return null;
      final value = int.tryParse(part, radix: 10);
      if (value == null || value < 0) return null;
      numbers.add(value);
    }
    return SemVer(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is SemVer &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releasePageUrl,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.apkSizeBytes,
  });

  final SemVer latestVersion;
  final String tagName;
  final String releasePageUrl;
  final String? releaseNotes;

  /// Null when the release has no `.apk` asset; the UI falls back to
  /// opening [releasePageUrl].
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
}

sealed class UpdateCheck {
  const UpdateCheck();
}

final class UpToDate extends UpdateCheck {
  const UpToDate();
}

final class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => 'UpdateException: $message';
}

/// Checks the app's GitHub releases for a newer version and downloads the
/// APK asset.
///
/// Installers are streamed to [workDirectory] rather than buffered — they
/// are tens of megabytes — written as a `.part` file and renamed only once
/// complete, so a crash never leaves a plausible-looking APK behind.
class AppUpdateService {
  AppUpdateService({
    required Directory workDirectory,
    http.Client Function()? clientFactory,
    Uri? latestReleaseUri,
    int maxApkBytes = defaultMaxApkBytes,
    Duration timeout = const Duration(seconds: 30),
    Duration overallDeadline = const Duration(minutes: 10),
  }) : _workDirectory = workDirectory,
       _clientFactory = clientFactory ?? http.Client.new,
       _latestReleaseUri = latestReleaseUri ?? _defaultLatestReleaseUri,
       _maxApkBytes = maxApkBytes,
       _timeout = timeout,
       _overallDeadline = overallDeadline;

  static final _defaultLatestReleaseUri = Uri.parse(
    'https://api.github.com/repos/zkwokleung/meme-library/releases/latest',
  );

  static const defaultMaxApkBytes = 200 * 1024 * 1024;

  /// Release JSON is a few KB; anything near this is not GitHub's answer.
  static const _maxMetadataBytes = 1024 * 1024;

  static const _connectionFailureMessage =
      'Could not check for updates. Check your connection.';
  static const _malformedReleaseMessage =
      'The release information could not be read.';

  final Directory _workDirectory;
  final http.Client Function() _clientFactory;
  final Uri _latestReleaseUri;
  final int _maxApkBytes;

  /// Idle timeout: applies to the headers and to each body chunk.
  final Duration _timeout;

  /// Hard ceiling for a whole download, so a server trickling bytes cannot
  /// hold the UI open forever.
  final Duration _overallDeadline;

  Future<UpdateCheck> checkForUpdate(String installedVersion) async {
    final installed = SemVer.tryParse(installedVersion);
    if (installed == null) {
      throw const UpdateException('Could not determine the installed version.');
    }

    final client = _clientFactory();
    try {
      final request = http.Request('GET', _latestReleaseUri)
        ..headers['Accept'] = 'application/vnd.github+json'
        ..headers['X-GitHub-Api-Version'] = '2022-11-28'
        // GitHub rejects requests without a User-Agent.
        ..headers['User-Agent'] = 'meme-library-app';
      final response = await client.send(request).timeout(_timeout);
      switch (response.statusCode) {
        case HttpStatus.ok:
          break;
        case HttpStatus.notFound:
          abandonResponse(response);
          throw const UpdateException('No releases found.');
        case HttpStatus.forbidden || HttpStatus.tooManyRequests:
          abandonResponse(response);
          throw const UpdateException(
            'GitHub rate limit reached. Try again later.',
          );
        default:
          abandonResponse(response);
          throw UpdateException(
            'The update check failed (status ${response.statusCode}).',
          );
      }

      final body = await _readMetadata(response).timeout(_overallDeadline);
      final info = _parseRelease(body);
      return info.latestVersion.compareTo(installed) > 0
          ? UpdateAvailable(info)
          : const UpToDate();
    } on TimeoutException {
      throw const UpdateException(_connectionFailureMessage);
    } on http.ClientException {
      throw const UpdateException(_connectionFailureMessage);
    } on IOException {
      throw const UpdateException(_connectionFailureMessage);
    } finally {
      client.close();
    }
  }

  Future<File> downloadApk(
    UpdateInfo info, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final apkUrl = info.apkDownloadUrl;
    if (apkUrl == null) {
      throw const UpdateException('This release has no Android installer.');
    }

    await _workDirectory.create(recursive: true);
    final apkFile = File(p.join(_workDirectory.path, '${info.tagName}.apk'));
    await _sweepStale(keep: p.basename(apkFile.path));

    // A leftover apk from an earlier attempt (e.g. the "Install unknown
    // apps" detour) is complete by construction: partials only ever exist
    // as `.part` files.
    if (await apkFile.exists()) {
      final length = await apkFile.length();
      if (info.apkSizeBytes == null || length == info.apkSizeBytes) {
        onProgress?.call(length, length);
        return apkFile;
      }
      await apkFile.delete();
    }

    final part = File(p.join(_workDirectory.path, '${info.tagName}.apk.part'));
    final client = _clientFactory();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(apkUrl)))
          .timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        abandonResponse(response);
        throw UpdateException(
          'The download failed (status ${response.statusCode}).',
        );
      }
      final declared = response.contentLength ?? info.apkSizeBytes;
      if (declared != null && declared > _maxApkBytes) {
        abandonResponse(response);
        throw const UpdateException('The update file is too large.');
      }

      sink = part.openWrite();
      var received = 0;
      // The deadline is checked inline rather than via `Future.timeout` so
      // an expired download cannot keep writing to a sink the error path
      // has already closed. The idle timeout bounds each check interval.
      final elapsed = Stopwatch()..start();
      await for (final chunk in response.stream.timeout(_timeout)) {
        if (elapsed.elapsed > _overallDeadline) {
          throw TimeoutException('update download deadline exceeded');
        }
        received += chunk.length;
        if (received > _maxApkBytes) {
          throw const UpdateException('The update file is too large.');
        }
        sink.add(chunk);
        onProgress?.call(received, declared);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (declared != null && received != declared) {
        throw const UpdateException('The download was interrupted. Try again.');
      }
      return await part.rename(apkFile.path);
    } on TimeoutException {
      throw const UpdateException('The download timed out. Try again.');
    } on http.ClientException {
      throw const UpdateException(
        'The download failed. Check your connection.',
      );
    } on IOException {
      throw const UpdateException(
        'The download failed. Check your connection.',
      );
    } finally {
      try {
        await sink?.close();
      } on IOException {
        // Already surfacing a more useful error.
      }
      if (await part.exists()) {
        try {
          await part.delete();
        } on IOException {
          // Stale sweep on the next download picks it up.
        }
      }
      client.close();
    }
  }

  /// Old `.apk`/`.part` files from previous versions or aborted attempts.
  Future<void> _sweepStale({String? keep}) async {
    await for (final entry in _workDirectory.list()) {
      if (entry is File && p.basename(entry.path) != keep) {
        try {
          await entry.delete();
        } on IOException {
          // Best effort; cacheDir is system-purgeable anyway.
        }
      }
    }
  }

  Future<Uint8List> _readMetadata(http.StreamedResponse response) async {
    final body = await readCapped(
      response.stream,
      maxBytes: _maxMetadataBytes,
      idleTimeout: _timeout,
    );
    if (body == null) {
      throw const UpdateException(_malformedReleaseMessage);
    }
    return body;
  }

  UpdateInfo _parseRelease(Uint8List bodyBytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bodyBytes));
    } on FormatException {
      throw const UpdateException(_malformedReleaseMessage);
    }
    if (decoded is! Map<String, Object?>) {
      throw const UpdateException(_malformedReleaseMessage);
    }
    final tagName = decoded['tag_name'];
    final htmlUrl = decoded['html_url'];
    if (tagName is! String || htmlUrl is! String) {
      throw const UpdateException(_malformedReleaseMessage);
    }
    final latest = SemVer.tryParse(tagName);
    if (latest == null) {
      throw const UpdateException(_malformedReleaseMessage);
    }

    String? apkUrl;
    int? apkSize;
    final assets = decoded['assets'];
    if (assets is List) {
      for (final entry in assets) {
        if (entry is! Map<String, Object?>) continue;
        final name = entry['name'];
        if (name is! String || !name.endsWith('.apk')) continue;
        final url = entry['browser_download_url'];
        if (url is! String) continue;
        final size = entry['size'];
        apkUrl = url;
        apkSize = size is int ? size : null;
        break;
      }
    }

    final notes = decoded['body'];
    return UpdateInfo(
      latestVersion: latest,
      tagName: tagName,
      releasePageUrl: htmlUrl,
      releaseNotes: notes is String && notes.isNotEmpty ? notes : null,
      apkDownloadUrl: apkUrl,
      apkSizeBytes: apkSize,
    );
  }
}
