import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/card.dart';

/// Renders a playing card face/back inside a [size] box at (0,0).
///
/// Cards use a tall-top layout: the rank sits in the top-left corner,
/// the suit symbol sits in the top-right corner, and a large suit symbol
/// is centred in the body below. No bottom-mirror corner — only the top
/// of each card stays visible when columns are fanned, so dropping the
/// mirror lets us shrink the card height without losing any information.
///
/// Suit symbols are drawn as **vector paths**, not Unicode glyphs. The
/// ♠♥♦♣ characters are intercepted by the system emoji font (Apple
/// Color Emoji on iOS/macOS, Segoe UI Emoji on Windows, browser emoji
/// fonts on web) which hard-codes red/black and refuses to honour our
/// [TextStyle.color]. The U+FE0E text-presentation selector is supposed
/// to disable this fallback but in practice it's spotty on iOS, so we
/// just draw the shapes ourselves.
class CardPainter {
  CardPainter._();

  static const Color faceBg = Color(0xFFFDFBF6);
  static const Color border = Color(0xFF1B1B1B);
  static const Color backOuter = Color(0xFF1B3B6F);
  static const Color backInner = Color(0xFF254F94);
  static const Color backHatch = Color(0xFFE3B341);
  static const Color shadow = Color(0x33000000);

  // Per-suit colours. Spades is the only black suit; everything else
  // gets a saturated hue that's still legible on the cream face.
  static const Color _spadesColor = Color(0xFF0E0E0E); // black
  static const Color _heartsColor = Color(0xFFC0252B); // red
  static const Color _diamondsColor = Color(0xFF1565C0); // blue
  static const Color _clubsColor = Color(0xFF2E7D32); // green

  static Color _colorForSuit(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return _spadesColor;
      case Suit.hearts:
        return _heartsColor;
      case Suit.diamonds:
        return _diamondsColor;
      case Suit.clubs:
        return _clubsColor;
    }
  }

  static void paintFront(Canvas canvas, Size size, PlayingCard card) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    canvas.drawRRect(
      rr.shift(const Offset(0, 1)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(rr, Paint()..color = faceBg);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = border.withValues(alpha: 0.7),
    );

    final color = _colorForSuit(card.suit);
    _paintTopRow(canvas, size, card, color);
    _paintCenter(canvas, size, card, color);
  }

  static void paintBack(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    canvas.drawRRect(
      rr.shift(const Offset(0, 1)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawRRect(rr, Paint()..color = backOuter);
    final inner = rr.deflate(5);
    canvas.drawRRect(inner, Paint()..color = backInner);

    canvas.save();
    canvas.clipRRect(inner);
    final hatch = Paint()
      ..color = backHatch.withValues(alpha: 0.35)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    const step = 9.0;
    for (var i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), hatch);
      canvas.drawLine(
          Offset(i, size.height), Offset(i + size.height, 0), hatch);
    }
    canvas.restore();

    final centre = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(centre, size.width * 0.22, Paint()..color = backOuter);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = backHatch;
    canvas.drawCircle(centre, size.width * 0.22, ring);
    canvas.drawCircle(centre, size.width * 0.14, ring);
    _drawSpiderGlyph(canvas, centre, size.width * 0.11, backHatch);

    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.4),
    );
  }

  /// Approximate height of the top corner row. Used by [_paintCenter]
  /// to reserve vertical space so the big centre suit doesn't crash
  /// into the rank/suit headers. Tuned to fit a 26pt rank.
  static const double _topRowHeight = 32.0;

  /// Draws the rank in the top-left corner and the suit symbol in the
  /// top-right corner — the two pieces of info that stay visible when
  /// cards fan downward in a column.
  static void _paintTopRow(
    Canvas canvas,
    Size size,
    PlayingCard card,
    Color color,
  ) {
    // Rank stays as text — letters don't have an emoji fallback so the
    // colour is honoured.
    final rankTp = _layoutText(
      card.rank.label,
      TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800),
    );
    rankTp.paint(canvas, const Offset(7, 2));

    // Suit symbol top-right as a vector path. The painted box is square
    // and roughly aligned with the cap-height of the rank text.
    const suitBox = 22.0;
    final suitX = size.width - suitBox - 7;
    const suitY = 5.0;
    _paintSuit(canvas, card.suit, color, suitX, suitY, suitBox);
  }

  /// Centres a large suit symbol in the body below the top row.
  static void _paintCenter(
    Canvas canvas,
    Size size,
    PlayingCard card,
    Color color,
  ) {
    final suitBox = size.width * 0.55;
    final suitX = (size.width - suitBox) / 2;
    final availableHeight = size.height - _topRowHeight;
    final suitY = _topRowHeight + (availableHeight - suitBox) / 2 - 2;
    _paintSuit(canvas, card.suit, color, suitX, suitY, suitBox);
  }

  /// Paints the suit shape filling a [side]×[side] square anchored at
  /// (x, y). The shape itself never touches the bounding box edges —
  /// each path has a small inset baked in so the antialiased outline
  /// doesn't clip.
  static void _paintSuit(
    Canvas canvas,
    Suit suit,
    Color color,
    double x,
    double y,
    double side,
  ) {
    final path = _suitPath(suit, side);
    canvas.save();
    canvas.translate(x, y);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  static Path _suitPath(Suit suit, double s) {
    switch (suit) {
      case Suit.spades:
        return _spadePath(s);
      case Suit.hearts:
        return _heartPath(s);
      case Suit.diamonds:
        return _diamondPath(s);
      case Suit.clubs:
        return _clubPath(s);
    }
  }

  /// Heart inscribed in [0, s] × [0, s]. Two lobes at the top meeting in
  /// a small dip, tapering to a single point at the bottom centre.
  static Path _heartPath(double s) {
    return Path()
      // Bottom point
      ..moveTo(s * 0.50, s * 0.90)
      // Left side: bottom → outer left → top-left lobe peak
      ..cubicTo(
        s * 0.00, s * 0.65,
        s * 0.00, s * 0.20,
        s * 0.22, s * 0.10,
      )
      // Left lobe → centre dip
      ..cubicTo(
        s * 0.36, s * 0.05,
        s * 0.45, s * 0.15,
        s * 0.50, s * 0.30,
      )
      // Centre dip → right lobe peak
      ..cubicTo(
        s * 0.55, s * 0.15,
        s * 0.64, s * 0.05,
        s * 0.78, s * 0.10,
      )
      // Right lobe → bottom
      ..cubicTo(
        s * 1.00, s * 0.20,
        s * 1.00, s * 0.65,
        s * 0.50, s * 0.90,
      )
      ..close();
  }

  /// Spade: vertically-mirrored heart with a triangular stem at the
  /// bottom. The lobes occupy the top ~70% of the canvas, the stem
  /// fills the bottom ~25%.
  static Path _spadePath(double s) {
    return Path()
      // Top point
      ..moveTo(s * 0.50, s * 0.05)
      // Right side: top → outer right → right lobe bottom
      ..cubicTo(
        s * 1.00, s * 0.30,
        s * 1.00, s * 0.65,
        s * 0.78, s * 0.72,
      )
      // Right lobe → centre bump
      ..cubicTo(
        s * 0.64, s * 0.76,
        s * 0.55, s * 0.68,
        s * 0.50, s * 0.55,
      )
      // Centre → left lobe
      ..cubicTo(
        s * 0.45, s * 0.68,
        s * 0.36, s * 0.76,
        s * 0.22, s * 0.72,
      )
      // Left lobe → back to top point
      ..cubicTo(
        s * 0.00, s * 0.65,
        s * 0.00, s * 0.30,
        s * 0.50, s * 0.05,
      )
      ..close()
      // Stem: flares from narrow at top to wide at bottom
      ..moveTo(s * 0.50, s * 0.55)
      ..lineTo(s * 0.68, s * 0.92)
      ..lineTo(s * 0.32, s * 0.92)
      ..close();
  }

  /// Diamond: rhombus with corners just inside the bounding box so the
  /// AA outline has a 1-px breathing room.
  static Path _diamondPath(double s) {
    return Path()
      ..moveTo(s * 0.50, s * 0.05)
      ..lineTo(s * 0.92, s * 0.50)
      ..lineTo(s * 0.50, s * 0.95)
      ..lineTo(s * 0.08, s * 0.50)
      ..close();
  }

  /// Club: three slightly-overlapping circles arranged in a triangle
  /// plus a triangular stem. The circles overlap by ~10% so the
  /// silhouette reads as one shape, not three.
  static Path _clubPath(double s) {
    final p = Path()
      // Top circle
      ..addOval(Rect.fromCircle(
        center: Offset(s * 0.50, s * 0.25),
        radius: s * 0.21,
      ))
      // Lower-left circle
      ..addOval(Rect.fromCircle(
        center: Offset(s * 0.28, s * 0.55),
        radius: s * 0.21,
      ))
      // Lower-right circle
      ..addOval(Rect.fromCircle(
        center: Offset(s * 0.72, s * 0.55),
        radius: s * 0.21,
      ))
      // Stem
      ..moveTo(s * 0.50, s * 0.55)
      ..lineTo(s * 0.68, s * 0.92)
      ..lineTo(s * 0.32, s * 0.92)
      ..close();
    return p;
  }

  static void _drawSpiderGlyph(
    Canvas canvas,
    Offset centre,
    double radius,
    Color color,
  ) {
    canvas.drawCircle(centre, radius * 0.6, Paint()..color = color);
    final leg = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * math.pi;
      final p2 = centre +
          Offset(math.cos(a) * radius * 1.6, math.sin(a) * radius * 1.6);
      canvas.drawLine(centre, p2, leg);
    }
  }

  static TextPainter _layoutText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
