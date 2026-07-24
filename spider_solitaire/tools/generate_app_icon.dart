// Generates assets/app_icon.png by rendering a Flutter widget tree.
//
// We use the flutter_test harness because it gives us a full painting
// pipeline (Canvas + TextPainter for the spade glyph) without needing a
// device or emulator. Run with:
//
//   flutter test tools/generate_app_icon.dart
//
// then `dart run flutter_launcher_icons` to fan the 1024×1024 source out
// to every platform icon set.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const double _kSize = 1024;

void main() {
  testWidgets('generate app icon', (tester) async {
    final boundaryKey = GlobalKey();
    // Minimal widget tree — Directionality + RepaintBoundary is all we
    // need to render. MaterialApp keeps scheduling ticks that hang
    // pumpAndSettle, so we avoid it.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundaryKey,
          child: const SizedBox(
            width: _kSize,
            height: _kSize,
            child: CustomPaint(painter: _AppIconPainter()),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary = boundaryKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final file = File('assets/app_icon.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('Wrote ${file.absolute.path} (${bytes.lengthInBytes} bytes)');
    });
  });
}

class _AppIconPainter extends CustomPainter {
  const _AppIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background — green felt gradient with rounded corners. The launcher
    // mask on each platform handles its own corner radius; baking one in
    // here keeps the rendered square looking polished if anything renders
    // the source unmasked (web favicons, splash screens, etc.).
    final bgRect = Rect.fromLTWH(0, 0, w, h);
    final bgRRect = RRect.fromRectAndRadius(bgRect, Radius.circular(w * 0.22));
    canvas.drawRRect(
      bgRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A8543), Color(0xFF093E1D)],
        ).createShader(bgRect),
    );

    // Card silhouette centred on the felt.
    final cardW = w * 0.64;
    final cardH = h * 0.80;
    final cardRect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: cardW,
      height: cardH,
    );
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(w * 0.06),
    );

    // Drop shadow.
    canvas.drawRRect(
      cardRRect.shift(Offset(0, w * 0.012)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.022),
    );

    // Card body + faint border.
    canvas.drawRRect(cardRRect, Paint()..color = const Color(0xFFFDFBF6));
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..color = const Color(0x66000000),
    );

    // Big black spade in the centre of the card. We use the actual ♠
    // glyph so it matches the in-game card painter exactly.
    final spadeTp = TextPainter(
      text: TextSpan(
        text: '♠',
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: w * 0.56,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    spadeTp.paint(
      canvas,
      Offset(
        (w - spadeTp.width) / 2,
        (h - spadeTp.height) / 2 + w * 0.015,
      ),
    );

    // Gold spider perched on the upper half of the spade.
    _drawSpider(
      canvas,
      Offset(w / 2, h * 0.43),
      w * 0.085,
      const Color(0xFFE3B341),
    );
  }

  void _drawSpider(
    Canvas canvas,
    Offset centre,
    double radius,
    Color color,
  ) {
    // Body.
    canvas.drawCircle(centre, radius * 0.65, Paint()..color = color);
    // Tiny eye highlights so the spider feels alive at small sizes.
    final eyePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(
        centre + Offset(-radius * 0.18, -radius * 0.18), radius * 0.07, eyePaint);
    canvas.drawCircle(
        centre + Offset(radius * 0.18, -radius * 0.18), radius * 0.07, eyePaint);
    // 8 legs radiating out — same layout as the card-back glyph but a
    // touch heavier so it reads at icon sizes.
    final leg = Paint()
      ..color = color
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * math.pi;
      final p =
          centre + Offset(math.cos(a) * radius * 1.7, math.sin(a) * radius * 1.7);
      canvas.drawLine(centre, p, leg);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
