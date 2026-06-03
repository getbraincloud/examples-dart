import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../models/card.dart';
import 'card_painter.dart';
import 'layout.dart';
import 'spider_game.dart';

/// Flame component representing a single playing card.
///
/// Drag handling is implemented here: when the user drags a face-up card,
/// the SpiderGame is asked to gather every card below it in the same
/// column and drag them as a group. On release, the game performs the
/// move (or snaps the group back if invalid).
class CardComponent extends PositionComponent
    with TapCallbacks, DragCallbacks {
  CardComponent({required this.card, required this.game})
      : super(size: Vector2(GameLayout.cardWidth, GameLayout.cardHeight));

  final PlayingCard card;
  final SpiderGame game;

  /// Column the card currently belongs to (set by the game on relayout).
  int column = -1;

  /// Index of the card within its column (0-based from top of column).
  int indexInColumn = -1;

  /// True while this card is the head of an active drag group.
  bool _draggingHead = false;

  /// Origin (in game coordinates) before a drag started — used to snap back.
  Vector2 _dragOrigin = Vector2.zero();

  /// When true, draws a yellow halo around the card. Toggled by hints.
  bool hinted = false;

  @override
  bool get debugMode => false;

  @override
  void onTapUp(TapUpEvent event) {
    if (!card.faceUp) return;
    game.autoMove(this);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!card.faceUp) return;
    final claimed = game.beginDrag(this);
    if (!claimed) return;
    _draggingHead = true;
    _dragOrigin = position.clone();
    priority = 1000;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_draggingHead) return;
    game.dragBy(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_draggingHead) return;
    _draggingHead = false;
    game.endDrag(_dragOrigin);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!_draggingHead) return;
    _draggingHead = false;
    game.endDrag(_dragOrigin, cancelled: true);
  }

  @override
  void render(Canvas canvas) {
    final s = Size(size.x, size.y);
    if (card.faceUp) {
      CardPainter.paintFront(canvas, s, card);
    } else {
      CardPainter.paintBack(canvas, s);
    }
    if (hinted) {
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD24A),
      );
    }
  }
}
