import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sticker_pack.dart';

/// Drives the pack list: summaries refreshed on any repository change.
class StickerPacksController extends AsyncNotifier<List<StickerPackSummary>> {
  Timer? _changeDebounce;
  int _generation = 0;

  @override
  Future<List<StickerPackSummary>> build() async {
    final repository = ref.watch(stickerPackRepositoryProvider);
    final subscription = repository.changes.listen((_) {
      _changeDebounce?.cancel();
      _changeDebounce = Timer(const Duration(milliseconds: 100), () {
        unawaited(_reload());
      });
    });
    ref.onDispose(() {
      subscription.cancel();
      _changeDebounce?.cancel();
    });
    return repository.allPacks();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final packs = await ref.read(stickerPackRepositoryProvider).allPacks();
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(packs);
    } catch (e, stackTrace) {
      if (ref.mounted && state.value == null) {
        state = AsyncError(e, stackTrace);
      }
    }
  }

  Future<StickerPack> createPack(String name) =>
      ref.read(stickerPackRepositoryProvider).createPack(name);

  Future<void> renamePack(String id, String name) =>
      ref.read(stickerPackRepositoryProvider).renamePack(id, name);

  Future<void> deletePack(String id) =>
      ref.read(stickerPackRepositoryProvider).deletePack(id);
}

final stickerPacksControllerProvider =
    AsyncNotifierProvider<StickerPacksController, List<StickerPackSummary>>(
      StickerPacksController.new,
    );

/// One pack with its items, refreshed on any repository change; null after
/// the pack is deleted.
final stickerPackDetailProvider = StreamProvider.family<StickerPack?, String>((
  ref,
  packId,
) async* {
  final repository = ref.watch(stickerPackRepositoryProvider);
  yield await repository.packById(packId);
  await for (final _ in repository.changes) {
    yield await repository.packById(packId);
  }
});
