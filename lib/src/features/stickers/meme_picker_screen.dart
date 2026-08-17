import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/library_query.dart';
import '../../domain/meme.dart';

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
  static const _pageSize = 60;

  final _items = <Meme>[];
  final _selected = <String>{};
  var _totalCount = 0;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    _loading = true;
    try {
      final page = await ref
          .read(libraryRepositoryProvider)
          .query(LibraryQuery(limit: _pageSize, offset: _items.length));
      if (!mounted) return;
      setState(() {
        _items.addAll(
          page.items.where((m) => !_items.any((e) => e.id == m.id)),
        );
        _totalCount = page.items.isEmpty ? _items.length : page.totalCount;
      });
    } finally {
      _loading = false;
    }
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
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No memes in the library yet'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                if (index >= _items.length - _pageSize ~/ 2 &&
                    _items.length < _totalCount) {
                  _loadMore();
                }
                final meme = _items[index];
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
