import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/meme.dart';
import 'import_coordinator.dart';

/// Streams an image over HTTPS and hands it to the import coordinator.
///
/// Responses are size-capped while streaming so oversized bodies are
/// abandoned early; timeouts and network errors surface as actionable
/// failures without partial library records.
class UrlImportService {
  UrlImportService(
    this._coordinator, {
    http.Client Function()? clientFactory,
    this.maxResponseBytes = defaultMaxResponseBytes,
    this.timeout = const Duration(seconds: 30),
    this.overallDeadline = const Duration(minutes: 2),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Mirrors `ImageValidator.defaultMaxFileSizeBytes`; larger downloads
  /// would be rejected by validation anyway.
  static const defaultMaxResponseBytes = 25 * 1024 * 1024;

  final ImportCoordinator _coordinator;
  final http.Client Function() _clientFactory;
  final int maxResponseBytes;

  /// Idle timeout: applies to the headers and to each body chunk.
  final Duration timeout;

  /// Hard ceiling for the whole download, so a server trickling bytes
  /// cannot hold the import open forever.
  final Duration overallDeadline;

  Future<ImportOutcome> importFromUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return const ImportFailure(
        ImportFailureReason.unsupportedFormat,
        'Enter a valid https:// link.',
      );
    }
    // Mobile platforms block cleartext HTTP by default (ATS on iOS,
    // usesCleartextTraffic on Android); fail with a clear message
    // instead of a misleading network error. Loopback stays allowed
    // (platform-exempt, and used by tests).
    if (uri.isScheme('http') && !_isLoopback(uri.host)) {
      return const ImportFailure(
        ImportFailureReason.unsupportedFormat,
        'Plain http:// links are not supported. Use an https:// link.',
      );
    }

    final client = _clientFactory();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(timeout);
      if (response.statusCode != 200) {
        _abandon(response);
        return ImportFailure(
          ImportFailureReason.network,
          'The server responded with status ${response.statusCode}.',
        );
      }
      final declared = response.contentLength;
      if (declared != null && declared > maxResponseBytes) {
        _abandon(response);
        return const ImportFailure(
          ImportFailureReason.tooLarge,
          'The file is too large to download.',
        );
      }

      final bytes = await _readCapped(response.stream).timeout(overallDeadline);
      if (bytes == null) {
        return const ImportFailure(
          ImportFailureReason.tooLarge,
          'The file is too large to download.',
        );
      }

      return await _coordinator.importBytes(
        bytes,
        sourceKind: MemeSourceKind.url,
        sourceRef: uri.toString(),
      );
    } on TimeoutException {
      return const ImportFailure(
        ImportFailureReason.network,
        'The download timed out. Check the link and try again.',
      );
    } on http.ClientException {
      return const ImportFailure(
        ImportFailureReason.network,
        'The image could not be downloaded. Check your connection.',
      );
    } on IOException {
      return const ImportFailure(
        ImportFailureReason.network,
        'The image could not be downloaded. Check your connection.',
      );
    } finally {
      client.close();
    }
  }

  static bool _isLoopback(String host) {
    if (host == 'localhost') return true;
    final address = InternetAddress.tryParse(host);
    return address != null && address.isLoopback;
  }

  /// Cancels the body of a response we decided not to read, releasing
  /// its connection instead of leaving it pinned until process exit.
  static void _abandon(http.StreamedResponse response) {
    unawaited(response.stream.listen(null).cancel());
  }

  /// Accumulates the stream, returning `null` once the cap is exceeded.
  Future<Uint8List?> _readCapped(http.ByteStream stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(timeout)) {
      builder.add(chunk);
      if (builder.length > maxResponseBytes) {
        return null;
      }
    }
    return builder.takeBytes();
  }
}
