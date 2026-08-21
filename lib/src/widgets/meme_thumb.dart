import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/meme.dart';

/// Hero tag linking a meme's tile to its detail screen.
String memeHeroTag(String memeId) => 'meme-$memeId';

/// Animated memes keep a GIF thumbnail; static ones get WebP/PNG.
bool memeIsAnimated(Meme meme) => meme.thumbnailPath.endsWith('.gif');

/// A meme thumbnail tile: image, placeholder, error fallback, and the
/// optional selection overlay, Hero, and animated badge — shared by the
/// library grid, sticker pack grid, meme picker, and pack list.
class MemeThumb extends ConsumerWidget {
  const MemeThumb({
    required this.meme,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 18,
    this.useHero = false,
    this.selectionMode = false,
    this.selected = false,
    this.showAnimatedBadge = false,
    super.key,
  });

  final Meme meme;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final bool useHero;
  final bool selectionMode;
  final bool selected;
  final bool showAnimatedBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStoreProvider);
    final colorScheme = Theme.of(context).colorScheme;

    Widget image = Image.file(
      media.resolve(meme.thumbnailPath),
      fit: BoxFit.cover,
      // Downsamples static thumbnails; a harmless no-op for animated GIF
      // thumbnails (the engine ignores the target size for multi-frame
      // codecs), which MediaStore already bounds to <=400px and <=48 frames.
      cacheWidth: 320,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
    if (useHero) {
      image = Hero(tag: memeHeroTag(meme.id), child: image);
    }

    return Semantics(
      label: meme.title ?? 'Meme',
      button: true,
      selected: selectionMode ? selected : null,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(borderRadius),
        color: colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (showAnimatedBadge)
                Positioned(
                  right: 8,
                  bottom: 8,
                  // Decorative: keep the tile's semantics label clean.
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // Scrim over arbitrary image pixels, deliberately the
                        // same in both brightnesses.
                        color: colorScheme.scrim.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'GIF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (selectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.24)
                        : Colors.transparent,
                    border: selected
                        ? Border.all(color: colorScheme.primary, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
