// Generates an animated GIF for manual device testing. Run with:
//
//   flutter test tool/make_test_gif.dart
//
// Writes build/test_anim.gif (a 6-frame moving-bar animation).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('write animated gif fixture', () {
    final encoder = img.GifEncoder();
    for (var i = 0; i < 6; i++) {
      final frame = img.Image(width: 240, height: 240);
      img.fill(frame, color: img.ColorRgb8(20 + i * 30, 40, 200 - i * 25));
      img.fillRect(
        frame,
        x1: i * 38,
        y1: 60,
        x2: i * 38 + 36,
        y2: 180,
        color: img.ColorRgb8(255, 230, 40),
      );
      encoder.addFrame(frame, duration: 25);
    }
    final file = File('build/test_anim.gif');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(encoder.finish()!);
    expect(file.lengthSync(), greaterThan(0));
  });
}
