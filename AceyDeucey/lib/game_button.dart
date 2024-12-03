import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_svg/flame_svg.dart';

class GameButton extends ButtonComponent {
  String iconPath = "";

  String? toggleIconPath;

  bool _toggled = false;

  SvgComponent icon = SvgComponent(priority: 5);

  Svg? iconSvg;
  Svg? toggledIconSvg;

  GameButton({required this.iconPath, this.toggleIconPath});

  @override
  FutureOr<void> onLoad() async {
    size = Vector2(80, 80);

    SpriteComponent btn = SpriteComponent();
    btn.sprite = await Sprite.load("btnSprite.png");
    SpriteComponent btnDown = SpriteComponent();
    btnDown.sprite = await Sprite.load("btnSpriteDown.png");

    button = PositionComponent();
    button?.add(btn);
    button?.size = size;
    buttonDown = PositionComponent();
    buttonDown?.add(btnDown);
    buttonDown?.size = size;

    if (toggleIconPath != null) {
      toggledIconSvg = await Svg.load(toggleIconPath!);
    }

    iconSvg = await Svg.load(iconPath);
    icon.svg = iconSvg;

    add(icon
      ..size = Vector2(48, 48)
      ..position = Vector2(16, 16));
    super.onLoad();
  }

  set toggled(val) {
    _toggled = val;

    if (_toggled && toggledIconSvg != null) {
      icon.svg = toggledIconSvg;
    } else {
      icon.svg = iconSvg;
    }
  }

  get toggled => _toggled;
}
