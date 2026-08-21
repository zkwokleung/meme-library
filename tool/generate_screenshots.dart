// Renders README screenshots from a seeded in-memory library. Run with:
//
//   flutter test tool/generate_screenshots.dart
//
// Outputs docs/screenshots/{library,detail,dark}.png (phone-sized, 3x).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/app/theme.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/domain/meme.dart' as domain;
import 'package:meme_library/src/features/detail/meme_detail_screen.dart';
import 'package:meme_library/src/import/import_coordinator.dart';

import '../test/helpers/test_harness.dart';

const _logicalSize = Size(390, 844);

/// A colorful abstract placeholder that reads as an image thumbnail.
Uint8List _demoImage(int seed, {int size = 512}) {
  final canvas = img.Image(width: size, height: size);
  final hues = [
    (img.ColorRgb8(255, 179, 71), img.ColorRgb8(255, 94, 98)),
    (img.ColorRgb8(102, 204, 255), img.ColorRgb8(98, 70, 234)),
    (img.ColorRgb8(255, 214, 98), img.ColorRgb8(255, 145, 77)),
    (img.ColorRgb8(129, 236, 178), img.ColorRgb8(38, 166, 154)),
    (img.ColorRgb8(244, 143, 177), img.ColorRgb8(156, 39, 176)),
    (img.ColorRgb8(179, 157, 219), img.ColorRgb8(63, 81, 181)),
  ];
  final (top, bottom) = hues[seed % hues.length];
  for (var y = 0; y < size; y++) {
    final t = y / size;
    final color = img.ColorRgb8(
      (top.r + (bottom.r - top.r) * t).round(),
      (top.g + (bottom.g - top.g) * t).round(),
      (top.b + (bottom.b - top.b) * t).round(),
    );
    for (var x = 0; x < size; x++) {
      canvas.setPixel(x, y, color);
    }
  }
  final white = img.ColorRgba8(255, 255, 255, 200);
  // The seed also skews each shape so every generated image is unique
  // (identical bytes would deduplicate on import).
  final skew = (seed * 13) % 60;
  switch (seed % 3) {
    case 0:
      img.fillCircle(
        canvas,
        x: size ~/ 2 + skew,
        y: size ~/ 2 - skew,
        radius: size ~/ 4,
        color: white,
      );
    case 1:
      img.fillRect(
        canvas,
        x1: size ~/ 4 + skew,
        y1: size ~/ 4,
        x2: size * 3 ~/ 4,
        y2: size * 3 ~/ 4 - skew,
        color: white,
        radius: size / 12,
      );
    default:
      img.drawLine(
        canvas,
        x1: size ~/ 5,
        y1: size * 4 ~/ 5 - skew,
        x2: size * 4 ~/ 5,
        y2: size ~/ 5 + skew,
        color: white,
        thickness: size / 10,
      );
  }
  return img.encodePng(canvas);
}

/// Loads real fonts from the Flutter SDK cache so screenshots don't render
/// with the Ahem placeholder font.
Future<void> _loadRealFonts() async {
  // resolvedExecutable:
  //   <sdk>/bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)
  final platformDir = File(Platform.resolvedExecutable).parent;
  final artifactsDir = platformDir.parent.parent;
  final fontsDir = Directory(
    '${artifactsDir.path}${Platform.pathSeparator}material_fonts',
  );
  if (!fontsDir.existsSync()) {
    throw StateError('Material fonts not found at ${fontsDir.path}');
  }
  final available = fontsDir.listSync().whereType<File>().toList();

  Future<void> loadFamily(String family, List<String> names) async {
    final loader = FontLoader(family);
    var found = false;
    for (final name in names) {
      final matches = available.where(
        (f) => f.path.toLowerCase().endsWith(name.toLowerCase()),
      );
      for (final file in matches) {
        found = true;
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    if (!found) throw StateError('No fonts for $family in ${fontsDir.path}');
    await loader.load();
  }

  await loadFamily('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await loadFamily('MaterialIcons', ['materialicons-regular.otf']);

  // Bundled display font: loaded from the repo, not the SDK cache.
  final display = FontLoader(kDisplayFontFamily);
  for (final path in [
    'assets/fonts/BricolageGrotesque-SemiBold.ttf',
    'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
  ]) {
    display.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await display.load();
}

void main() {
  testWidgets('generate screenshots', (tester) async {
    // Render real shadows instead of the test framework's black outlines.
    // Must be restored before the test body returns, so everything below
    // runs inside the try.
    debugDisableShadows = false;
    try {
      await _generate(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

Future<void> _generate(WidgetTester tester) async {
  {
    await tester.runAsync(_loadRealFonts);
    final harness = (await tester.runAsync(TestHarness.create))!;
    addTearDown(harness.dispose);

    final titles = [
      ('This is fine', ['reaction']),
      ('Distracted boyfriend', ['reaction', 'classic']),
      ('Success kid', ['wholesome']),
      ('Galaxy brain', ['classic']),
      ('Stonks', ['finance']),
      ('Good boy', ['dogs', 'wholesome']),
      ('Confused math lady', ['reaction']),
      ('Drake approves', ['classic']),
      ('Wholesome seal', ['wholesome']),
      ('Surprised pikachu', ['reaction']),
      ('Doge', ['dogs', 'classic']),
      ('Grumpy cat', ['classic']),
      ('Money printer', ['finance']),
      ('Hide the pain', ['reaction']),
      ('Sad cat thumbs up', ['wholesome']),
      ('Big brain time', ['reaction']),
      ('Fine, take my money', ['finance']),
      ('Happy dance', ['wholesome']),
    ];

    final memes = <domain.Meme>[];
    await tester.runAsync(() async {
      final coordinator = ImportCoordinator(
        repository: harness.repository,
        mediaStore: harness.mediaStore,
        pipeline: const InlineImagePipeline(),
      );
      for (var i = 0; i < titles.length; i++) {
        final outcome =
            await coordinator.importBytes(
                  _demoImage(i),
                  sourceKind: domain.MemeSourceKind.clipboard,
                )
                as ImportSuccess;
        var meme = await harness.repository.updateMetadata(
          outcome.meme.id,
          title: () => titles[i].$1,
        );
        meme = await harness.repository.setTags(meme.id, [
          for (final tag in titles[i].$2)
            await harness.repository.ensureTag(tag),
        ]);
        memes.add(meme);
      }
    });

    await tester.binding.setSurfaceSize(_logicalSize);
    tester.view.physicalSize = _logicalSize * 3;
    tester.view.devicePixelRatio = 3.0;

    final boundaryKey = GlobalKey();

    Future<void> pumpApp(Widget child) async {
      await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: child));
      // Let async state and image decoding land.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Decode every image the screen needs, then repaint from cache.
      // (Tool-only code; the context outliving awaits is safe here.)
      // ignore: use_build_context_synchronously
      await tester.runAsync(() async {
        final context = boundaryKey.currentContext!;
        for (final meme in memes) {
          final thumb = harness.mediaStore.resolve(meme.thumbnailPath);
          final original = harness.mediaStore.resolve(meme.relativePath);
          await precacheImage(
            ResizeImage(FileImage(thumb), width: 320),
            // ignore: use_build_context_synchronously
            context,
          );
          // ignore: use_build_context_synchronously
          await precacheImage(FileImage(original), context);
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> capture(String name) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    // -- Library (light).
    await pumpApp(
      ProviderScope(
        overrides: harness.overrides,
        child: const MemeLibraryApp(bindIncomingShares: false),
      ),
    );
    await capture('library');

    // -- Detail screen.
    await pumpApp(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: MemeDetailScreen(memeId: memes[1].id),
        ),
      ),
    );
    await capture('detail');

    // -- Library (dark).
    await pumpApp(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: ProviderScope(
          overrides: harness.overrides,
          child: const MemeLibraryApp(bindIncomingShares: false),
        ),
      ),
    );
    await capture('dark');
  }
}
