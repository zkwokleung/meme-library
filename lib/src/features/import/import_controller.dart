import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../import/import_coordinator.dart';
import '../../services/platform/incoming_share_service.dart';
import '../../services/providers.dart';

/// A user-facing summary of one import interaction.
class ImportFeedback {
  const ImportFeedback({required this.message, required this.isError});

  final String message;
  final bool isError;

  static ImportFeedback fromOutcomes(List<ImportOutcome> outcomes) {
    final added = outcomes
        .whereType<ImportSuccess>()
        .where((o) => !o.wasDuplicate)
        .length;
    final duplicates = outcomes
        .whereType<ImportSuccess>()
        .where((o) => o.wasDuplicate)
        .length;
    final failures = outcomes.whereType<ImportFailure>().toList();

    if (outcomes.length == 1) {
      return switch (outcomes.single) {
        ImportSuccess(wasDuplicate: true) => const ImportFeedback(
          message: 'Already in your library',
          isError: false,
        ),
        ImportSuccess() => const ImportFeedback(
          message: 'Added to your library',
          isError: false,
        ),
        ImportFailure(:final message) => ImportFeedback(
          message: message,
          isError: true,
        ),
      };
    }

    final parts = <String>[
      if (added > 0) '$added added',
      if (duplicates > 0) '$duplicates already saved',
      if (failures.isNotEmpty) '${failures.length} failed',
    ];
    return ImportFeedback(
      message: parts.isEmpty ? 'Nothing to import' : parts.join(' · '),
      isError: added == 0 && duplicates == 0,
    );
  }
}

/// Fired whenever an import finishes, so any screen can surface feedback.
final importFeedbackProvider = StreamProvider<ImportFeedback>(
  (ref) => ref.watch(importControllerProvider)._feedback.stream,
);

class ImportController {
  ImportController(this._ref);

  final Ref _ref;
  final _feedback = StreamController<ImportFeedback>.broadcast();
  StreamSubscription<Object?>? _sharesSubscription;
  bool _importing = false;

  bool get isImporting => _importing;

  Future<ImportFeedback> importFromClipboard() => _run(() async {
    final outcome = await _ref
        .read(clipboardImportServiceProvider)
        .importFromClipboard();
    return [outcome];
  });

  Future<ImportFeedback> importFromUrl(String url) => _run(() async {
    final outcome = await _ref
        .read(urlImportServiceProvider)
        .importFromUrl(url);
    return [outcome];
  });

  /// Starts listening for shares from other apps (cold and warm starts).
  Future<void> bindIncomingShares() async {
    final incoming = _ref.read(incomingShareServiceProvider);
    _sharesSubscription ??= incoming.incomingShares.listen((files) {
      if (files.isNotEmpty) unawaited(_importShared(files));
    });
    final initial = await incoming.takeInitialShares();
    if (initial.isNotEmpty) await _importShared(initial);
  }

  Future<void> _importShared(List<IncomingSharedFile> files) => _run(() async {
    final service = _ref.read(shareImportServiceProvider);
    return service.importShared(files);
  });

  Future<ImportFeedback> _run(
    Future<List<ImportOutcome>> Function() body,
  ) async {
    _importing = true;
    try {
      final feedback = ImportFeedback.fromOutcomes(await body());
      _feedback.add(feedback);
      return feedback;
    } finally {
      _importing = false;
    }
  }

  void dispose() {
    _sharesSubscription?.cancel();
    _feedback.close();
  }
}

final importControllerProvider = Provider<ImportController>((ref) {
  final controller = ImportController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
