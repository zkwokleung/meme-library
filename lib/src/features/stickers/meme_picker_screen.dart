import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meme.dart';
import '../library/library_controller.dart';
import '../library/meme_pager.dart';

/// Full-screen multi-select over the library; pops with the picked meme
/// ids, or null on back. Animated memes cannot become static stickers, so
/// their tiles are disabled and badged.
class MemePickerScreen extends ConsumerStatefulWidget {
  const MemePickerScreen({super.key});

  static Future<List<String>?> pick(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const MemePickerScreen()));

  @override
  ConsumerState<MemePickerScreen> createState() => _MemePickerScreenState();
}

class _MemePickerScreenState extends ConsumerState<MemePickerScreen> {
  late final MemePager _pager = MemePager(
    repository: ref.read(libraryRepositoryProvider),
    onUpdate: () {
      if (mounted) setState(() {});
    },
    // Memes mid delete-with-undo must not be added to a pack; the delete
    // would silently cascade them back out.
    hiddenIds: () =>
        ref.read(libraryControllerProvider.notifier).pendingDeleteIds,
  );

  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_pager.refresh());
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool _isAnimated(Meme meme) => meme.thumbnailPath.endsWith('.gif');

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty ? 'Pick memes' : '${_selected.length} selected',
        ),
        actions: [
          IconButton(
            tooltip: 'Add to pack',
            icon: const Icon(Icons.check),
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Search memes',
              leading: const Icon(Icons.search),
              onChanged: _pager.setSearchText,
            ),
          ),
        ),
      ),
      body: !_pager.initialized
          ? const Center(child: CircularProgressIndicator())
          : _pager.items.isEmpty
          ? Center(
              child: Text(
                _pager.searchText.isEmpty
                    ? 'No memes in the library yet'
                    : 'No memes match your search',
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _pager.items.length,
              itemBuilder: (context, index) {
                if (index >= _pager.items.length - _pager.pageSize ~/ 2 &&
                    _pager.hasMore) {
                  unawaited(_pager.loadMore());
                }
                final meme = _pager.items[index];
                final animated = _isAnimated(meme);
                final selected = _selected.contains(meme.id);
                return GestureDetector(
                  onTap: animated
                      ? null
                      : () => setState(() {
                          if (!_selected.remove(meme.id)) {
                            _selected.add(meme.id);
                          }
                        }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: animated ? 0.35 : 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            media.resolve(meme.thumbnailPath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (animated)
                        const Center(
                          child: Chip(
                            label: Text('Animated'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (selected)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
