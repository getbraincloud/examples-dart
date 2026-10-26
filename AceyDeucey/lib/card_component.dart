import 'dart:async';

import 'package:flame/components.dart' hide Timer;
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class CardComponent extends RectangleComponent {
  SvgComponent cardBG = SvgComponent();
  SvgComponent cardFace = SvgComponent();

  late Svg cardBGSvgUp;
  late Svg cardBGSvgDown;

  SpriteGroupComponent cardBack = SpriteGroupComponent();

  final _CardBorder _resultBorder = _CardBorder(priority: 10);

  static const Color defaultBorderColor = Colors.black;
  static const Color winBorderColor = Color(0xFF32CD32);
  static const Color outsideWinBorderColor = Colors.indigo;
  static const Color postBorderColor = Colors.red;

  // Geometry of the rounded rect drawn inside cardBG.svg/cardBGDown.svg,
  // normalized to each SVG's own viewBox (both share these rect values, only
  // their viewBox dimensions differ), so the result border can be computed
  // to sit directly on top of whichever art is currently showing.
  static const double _svgRectX = 0.25630665;
  static const double _svgRectY = 0.2563068;
  static const double _svgRectW = 15.362386;
  static const double _svgRectH = 16.420719;
  static const double _svgRectRadius = 1.7221595;

  final cardImages = {
    2: "FaceCards_2.svg",
    3: "FaceCards_3.svg",
    4: "FaceCards_4.svg",
    5: "FaceCards_5.svg",
    6: "FaceCards_6.svg",
    7: "FaceCards_7.svg",
    8: "FaceCards_8.svg",
    9: "FaceCards_9.svg",
    10: "FaceCards_10.svg",
    11: "FaceCards_Jack.svg",
    12: "FaceCards_Queen.svg",
    13: "FaceCards_King.svg",
    14: "FaceCards_Ace_Blue.svg"
  };

  int value = 0;
  String suit = "";
  double origX = 0.0;

  bool isFlipping = false; // Prevents multiple flips at the same time.
  double flipProgress = 1.0; // 1.0 (visible) -> 0.0 (flat) -> -1.0 (flipped).
  final double flipDuration = 0.20; // Duration of the flip animation.

  @override
  FutureOr<void> onLoad() async {
    size = Vector2(160, 170);

    setColor(Colors.transparent);

    cardBGSvgUp = await Svg.load("images/cardBG.svg");
    cardBGSvgDown = await Svg.load("images/cardBGDown.svg");

    cardBG
      ..svg = cardBGSvgUp
      ..size = size;

    add(cardBG);

    add(cardFace
      ..size = size - Vector2(18, 18)
      ..x = 12
      ..y = 12);

    Sprite empty = await Sprite.load('empty.png');
    Sprite cardLogo = await Sprite.load('AD_bcLogo_dark.png');

    add(cardBack
      ..sprites = {
        CardState.faceDown: cardLogo,
        CardState.faceUp: empty,
      }
      ..current = CardState.faceDown
      ..size = Vector2(100, 109)
      ..x = 28
      ..y = 28);

    add(_resultBorder);
    _fitBorderTo(cardBGSvgUp);

    super.onLoad();
  }

  /// Repositions/resizes [_resultBorder] to sit exactly on top of [svg]'s own
  /// rounded rect. cardBG.svg and cardBGDown.svg share the same rect values
  /// but have different (non-square) viewBoxes, so this must be recomputed
  /// against whichever art is actually showing rather than assumed once.
  void _fitBorderTo(Svg svg) {
    final nativeSize = svg.pictureInfo.size;

    final double scaleX = size.x / nativeSize.width;
    final double scaleY = size.y / nativeSize.height;
    final double fitScale = scaleX < scaleY ? scaleX : scaleY;

    final double fitOffsetX = (size.x - nativeSize.width * fitScale) / 2;
    final double fitOffsetY = (size.y - nativeSize.height * fitScale) / 2;

    _resultBorder
      ..position = Vector2(
          fitOffsetX + _svgRectX * fitScale, fitOffsetY + _svgRectY * fitScale)
      ..size = Vector2(_svgRectW * fitScale, _svgRectH * fitScale)
      ..cornerRadius = _svgRectRadius * fitScale;
  }

  /// Colors the card's border to indicate a win/loss/post result. Pass null
  /// to reset to the default border.
  void setResultBorder(Color? color) {
    _resultBorder.paint = Paint()
      ..color = color ?? defaultBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
  }

  void cardValue(PlayingCard playingCard) {
    value = playingCard.value;
    suit = playingCard.suit;

    if (value > 0) {
      // cardBack.current = CardState.faceUp;
      // svg = "images/${cardImages[value]}";
      // cardBG.svg = cardBGSvgUp;
      flipCard();
    } else {
      cardFace.svg = null;
      cardBack.current = CardState.faceDown;
      cardBG.svg = cardBGSvgDown;
      _fitBorderTo(cardBGSvgDown);
      setResultBorder(null);
    }
  }

  set svg(String svgPath) {
    Svg.load(svgPath).then((svg) => cardFace.svg = svg);
  }

  /// Flip function to visually flip the card.
  void flipCard() {
    if (isFlipping) return; // Prevent overlapping animations.
    origX = x;
    isFlipping = true;
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final delta = 16 / (flipDuration * 1000);
      flipProgress -= delta;

      // At halfway point, swap the card state.
      if (flipProgress <= 0 && flipProgress > -delta) {
        if (cardBack.current == CardState.faceDown) {
          cardBack.current = CardState.faceUp;
          svg = "images/${cardImages[value]}";
          cardBG.svg = cardBGSvgUp;
          _fitBorderTo(cardBGSvgUp);
        } else {
          cardBack.current = CardState.faceDown;
          cardFace.svg = null;
          cardBG.svg = cardBGSvgDown;
          _fitBorderTo(cardBGSvgDown);
        }
      }

      // Reset animation and mark as done.
      if (flipProgress <= -1.0) {
        flipProgress = 1.0;
        isFlipping = false;
        timer.cancel();
      }

      // Update the component's visual scale.
      scale.x = flipProgress.abs();
      if (!isFlipping) {
        x = origX;
      } else {
        // var xd1 =
        var xd = (width / 10) *
            (1 - ((flipProgress.abs() * 10.0).roundToDouble()) / 10.0);
        if (flipProgress > 0) {
          x += xd;
        } else {
          x -= xd;
        }
      }
    });
  }
}

enum CardState { faceDown, faceUp }

/// Draws a stroked, rounded-rect border directly on top of the card's own
/// rounded rect (position/size/cornerRadius set to match it exactly).
class _CardBorder extends PositionComponent {
  _CardBorder({super.priority});

  double cornerRadius = 16;

  Paint paint = Paint()
    ..color = CardComponent.defaultBorderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void render(Canvas canvas) {
    final radius = Radius.circular(cornerRadius);
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), radius), paint);
  }
}
