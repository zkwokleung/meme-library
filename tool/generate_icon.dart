// Renders the app icon to PNG files. Run with:
//
//   flutter test tool/generate_icon.dart
//
// Outputs (committed to the repo, consumed by flutter_launcher_icons):
//   assets/icon/app_icon.png        1024x1024 full icon
//   assets/icon/app_icon_fg.png     1024x1024 adaptive foreground (transparent)
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

void main() {
  testWidgets('generate app icons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_size, _size));
    tester.view.physicalSize = const Size(_size, _size);
    tester.view.devicePixelRatio = 1.0;

    Future<void> capture(Widget widget, String path) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(_size, _size)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: widget,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    await capture(
      const _AppIcon(withBackground: true),
      'assets/icon/app_icon.png',
    );
    await capture(
      const _AppIcon(withBackground: false),
      'assets/icon/app_icon_fg.png',
    );
  });
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.withBackground});

  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(painter: _IconPainter(withBackground: withBackground)),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter({required this.withBackground});

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);

    if (withBackground) {
      final bg = Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(s, s), [
          const Color(0xFFF0703F),
          const Color(0xFFC43E14),
        ]);
      canvas.drawRect(Rect.fromLTWH(0, 0, s, s), bg);
    }

    // Adaptive foregrounds must keep content inside the central 66% safe
    // zone; the full icon can breathe a little more.
    final scale = withBackground ? 1.0 : 0.78;
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    final cardSize = s * 0.52;
    final cardRect = Rect.fromCenter(
      center: center,
      width: cardSize,
      height: cardSize,
    );
    final radius = Radius.circular(s * 0.09);

    // Back card: tilted, translucent white.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-10 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.shift(Offset(-s * 0.045, 0)), radius),
      Paint()..color = const Color(0x59FFFFFF),
    );
    canvas.restore();

    // Front card: white, slightly rotated the other way.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(4 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    final front = cardRect.shift(Offset(s * 0.03, s * 0.01));
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, radius),
      Paint()..color = Colors.white,
    );

    // Smiley on the front card.
    final vermilion = Paint()..color = const Color(0xFFC43E14);
    final eyeRadius = front.width * 0.075;
    final eyeY = front.center.dy - front.height * 0.13;
    canvas.drawCircle(
      Offset(front.center.dx - front.width * 0.2, eyeY),
      eyeRadius,
      vermilion,
    );
    canvas.drawCircle(
      Offset(front.center.dx + front.width * 0.2, eyeY),
      eyeRadius,
      vermilion,
    );
    final mouth = Paint()
      ..color = const Color(0xFFC43E14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = front.width * 0.085
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(front.center.dx, front.center.dy + front.height * 0.08),
        width: front.width * 0.52,
        height: front.height * 0.42,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      mouth,
    );
    canvas.restore();

    // Sparkle, top right: a four-point star.
    final sparkleCenter = Offset(s * 0.76, s * 0.24);
    final sparkle = Path();
    final r1 = s * 0.075;
    final r2 = s * 0.026;
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? r1 : r2;
      final angle = i * math.pi / 4 - math.pi / 2;
      final point = Offset(
        sparkleCenter.dx + r * math.cos(angle),
        sparkleCenter.dy + r * math.sin(angle),
      );
      if (i == 0) {
        sparkle.moveTo(point.dx, point.dy);
      } else {
        sparkle.lineTo(point.dx, point.dy);
      }
    }
    sparkle.close();
    // Cream, not amber: amber vanishes against the vermilion field.
    canvas.drawPath(sparkle, Paint()..color = const Color(0xFFFFF6E8));
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}
