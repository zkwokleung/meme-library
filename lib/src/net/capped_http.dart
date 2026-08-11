import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Cancels the body of a response we decided not to read, releasing its
/// connection instead of leaving it pinned until process exit.
void abandonResponse(http.StreamedResponse response) {
  unawaited(response.stream.listen(null).cancel());
}

/// Accumulates [stream] with [idleTimeout] applied between chunks,
/// returning null once [maxBytes] is exceeded.
Future<Uint8List?> readCapped(
  http.ByteStream stream, {
  required int maxBytes,
  required Duration idleTimeout,
}) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream.timeout(idleTimeout)) {
    builder.add(chunk);
    if (builder.length > maxBytes) {
      return null;
    }
  }
  return builder.takeBytes();
}
