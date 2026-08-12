import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/features/library/library_controller.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late ProviderContainer container;

  setUp(() async {
    harness = await TestHarness.create();
    container = ProviderContainer(overrides: harness.overrides);
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  /// Keeps the provider alive and waits for the initial load.
  Future<LibraryState> ready() {
    container.listen(libraryControllerProvider, (_, _) {});
    return container.read(libraryControllerProvider.future);
  }

  LibraryState state() => container.read(libraryControllerProvider).requireValue;

  LibraryController controller() =>
      container.read(libraryControllerProvider.notifier);

  /// Polls until [condition] holds; covers the controller's 100ms
  /// change-stream debounce plus the reload query.
  Future<void> waitUntil(bool Function() condition) async {
    for (var i = 0; i < 150 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue);
  }

  Future<(Meme, Meme)> seedTwo() async {
    final a = await harnessImport(harness, seed: 1);
    final b = await harnessImport(harness, seed: 2);
    return (a, b);
  }

  test('toggleSelected enters and exits selection mode', () async {
    final (a, _) = await seedTwo();
    await ready();

    expect(state().selectionMode, isFalse);

    controller().toggleSelected(a.id);
    expect(state().selectionMode, isTrue);
    expect(state().selectedIds, {a.id});

    controller().toggleSelected(a.id);
    expect(state().selectionMode, isFalse);
    expect(state().selectedIds, isEmpty);
  });

  test('toggleSelected ignores ids that are not visible', () async {
    await seedTwo();
    await ready();

    controller().toggleSelected('no-such-meme');
    expect(state().selectedIds, isEmpty);
  });

  test('clearSelection empties the selection', () async {
    final (a, b) = await seedTwo();
    await ready();

    controller()
      ..toggleSelected(a.id)
      ..toggleSelected(b.id);
    expect(state().selectedIds, hasLength(2));

    controller().clearSelection();
    expect(state().selectedIds, isEmpty);
  });

  test('a reload prunes selected ids that vanished', () async {
    final (a, b) = await seedTwo();
    await ready();

    controller()
      ..toggleSelected(a.id)
      ..toggleSelected(b.id);

    await harness.repository.deleteMeme(a.id);
    await waitUntil(() => state().items.length == 1);

    expect(state().selectedIds, {b.id});
  });

  test('a filter change prunes selected ids that fell out of view', () async {
    final (a, b) = await seedTwo();
    final tag = await harness.repository.ensureTag('kept');
    await harness.repository.setTags(b.id, [tag]);
    await ready();

    controller().toggleSelected(a.id);
    await controller().toggleTag(tag.id);

    expect(state().items.map((m) => m.id), [b.id]);
    expect(state().selectedIds, isEmpty);
    expect(state().selectionMode, isFalse);
  });

  test('deleteManyWithUndo hides all selected in one update', () async {
    final (a, b) = await seedTwo();
    await ready();

    controller()
      ..toggleSelected(a.id)
      ..toggleSelected(b.id);
    final ids = controller().deleteManyWithUndo(
      state().selectedItems,
      undoWindow: const Duration(milliseconds: 200),
    );

    expect(ids.toSet(), {a.id, b.id});
    expect(state().items, isEmpty);
    expect(state().totalCount, 0);
    expect(state().selectionMode, isFalse);

    // The deletions commit after the undo window plus its grace margin.
    for (var i = 0; i < 400; i++) {
      if (await harness.repository.memeCount() == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await harness.repository.memeCount(), 0);
  });

  test('undoDeleteMany restores every pending deletion', () async {
    final (a, b) = await seedTwo();
    await ready();

    controller()
      ..toggleSelected(a.id)
      ..toggleSelected(b.id);
    final ids = controller().deleteManyWithUndo(state().selectedItems);
    expect(state().items, isEmpty);

    controller().undoDeleteMany(ids);
    await waitUntil(() => state().items.length == 2);
    expect(await harness.repository.memeCount(), 2);
  });

  test('addTagToSelected tags the selection and clears it', () async {
    final (a, b) = await seedTwo();
    await ready();

    controller()
      ..toggleSelected(a.id)
      ..toggleSelected(b.id);
    final count = await controller().addTagToSelected('bulk');

    expect(count, 2);
    expect(state().selectedIds, isEmpty);
    expect((await harness.repository.memeById(a.id))!.tags.single.name, 'bulk');
    expect((await harness.repository.memeById(b.id))!.tags.single.name, 'bulk');
  });

  test('addTagToSelected without a selection is a no-op', () async {
    await seedTwo();
    await ready();

    expect(await controller().addTagToSelected('bulk'), 0);
    expect(await harness.repository.allTags(), isEmpty);
  });
}
