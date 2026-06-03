import 'package:flame/components.dart';

/// Virtual coordinate system used by SpiderGame. The viewport scales this
/// to fit the available screen, so all positioning lives in one fixed space.
class GameLayout {
  static const double virtualWidth = 1100;
  static const double virtualHeight = 820;

  static const double cardWidth = 102;

  // Cards no longer carry a bottom-right mirror of the corner index, so
  // we can drop the height substantially without losing any visible
  // information. The smaller bottom card also frees ~30px of vertical
  // headroom for long tableau columns.
  static const double cardHeight = 112;
  static const double faceUpFan = 31;
  static const double faceDownFan = 13;

  static const double sidePadding = 6;
  static const double tableauTop = 22;

  /// Horizontal centre-to-centre gap between adjacent tableau columns.
  static double get columnSpacing =>
      (virtualWidth - 2 * sidePadding - cardWidth) / 9;

  static Vector2 columnOrigin(int column) => Vector2(
        sidePadding + columnSpacing * column,
        tableauTop,
      );

  static Vector2 foundationSlot(int index) => Vector2(
        sidePadding + (cardWidth + 8) * index,
        virtualHeight - cardHeight - 16,
      );

  static Vector2 stockPosition() => Vector2(
        virtualWidth - sidePadding - cardWidth,
        virtualHeight - cardHeight - 16,
      );
}
