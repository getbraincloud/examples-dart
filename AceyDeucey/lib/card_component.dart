import 'dart:async' as Async;

import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class CardComponent extends RectangleComponent {
  SvgComponent cardBG = SvgComponent();
  SvgComponent cardFace = SvgComponent();

  late Svg cardBGSvgUp;
  late Svg cardBGSvgDown;

  SpriteGroupComponent cardBack = SpriteGroupComponent();

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

  bool isFlipping = false; // Prevents multiple flips at the same time.
  double flipProgress = 1.0; // 1.0 (visible) -> 0.0 (flat) -> -1.0 (flipped).
  final double flipDuration = 0.3; // Duration of the flip animation.

  @override
  Async.FutureOr<void> onLoad() async {
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

    super.onLoad();
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
    }
  }

  set svg(String svgPath) {
    Svg.load(svgPath).then((svg) => cardFace.svg = svg);
  }

  /// Flip function to visually flip the card.
  void flipCard() {
    if (isFlipping) return; // Prevent overlapping animations.

    isFlipping = true;
    Async.Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final delta = 16 / (flipDuration * 1000);
      flipProgress -= delta;

      // At halfway point, swap the card state.
      if (flipProgress <= 0 && flipProgress > -delta) {
        if (cardBack.current == CardState.faceDown) {
          cardBack.current = CardState.faceUp;
          svg = "images/${cardImages[value]}";
          cardBG.svg = cardBGSvgUp;
        } else {
          cardBack.current = CardState.faceDown;
          cardFace.svg = null;
          cardBG.svg = cardBGSvgDown;
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
    });
  }

}

enum CardState { faceDown, faceUp }
