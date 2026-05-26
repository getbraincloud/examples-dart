import 'dart:async' as async;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/card.dart';
import '../models/difficulty.dart';
import '../models/game_state.dart';
import '../models/scoring_config.dart';
import 'card_component.dart';
import 'layout.dart';

typedef GameWonCallback = void Function(int score, int seconds, int moves);

/// Outcome of [SpiderGame.showHint].
enum HintResult {
  /// A meaningful move was found — the source card group is highlighted.
  shown,

  /// No move advances the board but the stock can still be dealt — the
  /// stock pile is highlighted to nudge the player toward dealing.
  dealFromStock,

  /// No advancing moves and the stock is empty. The game is stuck.
  gameOver,

  /// An animation (deal, move, or foundation cascade) is in progress.
  busy,
}

/// FlameGame that owns the Spider Solitaire board: it renders cards,
/// handles drag-and-drop input, and notifies on win.
class SpiderGame extends FlameGame {
  SpiderGame({
    required this.difficulty,
    this.scoring = const ScoringConfig(),
    this.onWon,
    this.onChanged,
    this.onGameOver,
    double? screenAspect,
    int? seed,
  })  : virtualHeight = _resolveVirtualHeight(screenAspect),
        state = SpiderGameState(
          difficulty: difficulty,
          seed: seed,
          scoring: scoring,
        );

  final Difficulty difficulty;

  /// Scoring weights handed to every [SpiderGameState] this game
  /// creates (including the ones spun up by [restart]).
  final ScoringConfig scoring;

  final GameWonCallback? onWon;
  final VoidCallback? onChanged;

  /// Fires once when the game enters a stuck state — no advancing moves
  /// and the stock is empty. The host screen typically responds with a
  /// "Game Over" dialog. Not called on win.
  final VoidCallback? onGameOver;

  /// Virtual canvas height. Falls back to [GameLayout.virtualHeight] when
  /// no screen aspect is provided. When the host screen passes its actual
  /// aspect we shrink the height so the virtual aspect matches the screen,
  /// which eliminates side-bar letterboxing on phone landscape (16:9 /
  /// 19.5:9). Tablets in 4:3 land at the default height so they look the
  /// same as before.
  final double virtualHeight;

  static double _resolveVirtualHeight(double? screenAspect) {
    const fallback = GameLayout.virtualHeight;
    if (screenAspect == null || screenAspect <= 0) return fallback;
    final fitted = GameLayout.virtualWidth / screenAspect;
    // Clamp so tableau still has room (lower) and never grows taller than
    // the original (upper).
    return fitted.clamp(500.0, fallback);
  }

  SpiderGameState state;

  /// Y coordinate of the foundation/stock row in virtual units.
  /// Y coordinate of the foundation/stock row. Hugged to the very bottom
  /// of the virtual canvas so tableau columns get the maximum possible
  /// vertical room above them.
  double get _slotRowY => virtualHeight - GameLayout.cardHeight;

  /// Position of foundation slot [index] using the dynamic [virtualHeight].
  Vector2 _foundationSlot(int index) => Vector2(
        GameLayout.sidePadding + (GameLayout.cardWidth + 8) * index,
        _slotRowY,
      );

  /// Position of the stock pile using the dynamic [virtualHeight].
  Vector2 _stockPos() => Vector2(
        GameLayout.virtualWidth -
            GameLayout.sidePadding -
            GameLayout.cardWidth,
        _slotRowY,
      );

  /// True when the game is laid out for short screens (phone landscape).
  /// In compact mode we reserve extra room on the left of the tableau so
  /// the floating back-button overlay doesn't sit on top of column 0.
  bool get _isCompactLayout => virtualHeight < 700;

  /// Effective left padding of the tableau in virtual units. Bigger in
  /// compact mode to keep column 0 clear of the back-button overlay.
  double get _tableauLeftPadding =>
      _isCompactLayout ? 60 : GameLayout.sidePadding;

  /// Effective right padding of the tableau. In compact mode we drop it
  /// to 0 so the wider left padding doesn't squeeze inter-column gaps
  /// below the minimum readable spacing.
  double get _tableauRightPadding =>
      _isCompactLayout ? 0 : GameLayout.sidePadding;

  /// Horizontal centre-to-centre spacing of tableau columns, recomputed
  /// from the effective padding so 10 columns still span the full canvas.
  double get _tableauColumnSpacing =>
      (GameLayout.virtualWidth -
              _tableauLeftPadding -
              _tableauRightPadding -
              GameLayout.cardWidth) /
          9;

  /// Top-left position of tableau column [column] in virtual units.
  /// Replaces [GameLayout.columnOrigin] which uses a fixed padding.
  Vector2 _columnOrigin(int column) => Vector2(
        _tableauLeftPadding + _tableauColumnSpacing * column,
        GameLayout.tableauTop,
      );

  /// True while an animation is in flight; drag input is gated on this.
  bool _animating = false;
  bool get isAnimating => _animating;

  final Map<PlayingCard, CardComponent> _byCard = {};
  final List<GameSnapshot> _undoStack = [];
  async.Timer? _hintTimer;

  bool get canUndo => _undoStack.isNotEmpty && !_animating;

  /// Cards currently being dragged together (top → bottom in column order).
  final List<CardComponent> _dragGroup = [];

  /// (column, index) the drag group originated from.
  int _dragFromColumn = -1;
  int _dragFromIndex = -1;

  /// Visual stack representing the stock pile (for tap-to-deal).
  late final _StockComponent _stockArea;

  @override
  Color backgroundColor() => const Color(0xFF0E5A2B);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(GameLayout.virtualWidth, virtualHeight),
    );

    final slotSize = Vector2(GameLayout.cardWidth, GameLayout.cardHeight);
    for (var i = 0; i < 8; i++) {
      world.add(_FoundationComponent()
        ..position = _foundationSlot(i)
        ..size = slotSize);
    }
    for (var i = 0; i < 10; i++) {
      world.add(_ColumnSlot()
        ..position = _columnOrigin(i)
        ..size = slotSize);
    }

    _stockArea = _StockComponent(game: this)
      ..position = _stockPos()
      ..size = slotSize;
    world.add(_stockArea);

    _rebuildAll(animateInitialDeal: true);
  }

  void restart({int? seed}) {
    state = SpiderGameState(
      difficulty: difficulty,
      seed: seed,
      scoring: scoring,
    );
    _undoStack.clear();
    _clearHint();
    _rebuildAll(animateInitialDeal: true);
    onChanged?.call();
  }

  /// Undoes the most recent move or stock deal.
  void undo() {
    if (!canUndo) return;
    _clearHint();
    final snap = _undoStack.removeLast();
    state.restore(snap);
    _relayout();
    onChanged?.call();
  }

  /// Auto-move: places the group whose head is [head] onto the best legal
  /// target column. "Best" is the valid target with the longest same-suit
  /// descending run at its bottom; ties go to the leftmost column. Empty
  /// columns are last resort.
  void autoMove(CardComponent head) {
    if (_animating) return;
    _clearHint();
    final fromCol = head.column;
    final fromIdx = head.indexInColumn;
    if (fromCol < 0) return;
    if (!state.isMovableGroup(fromCol, fromIdx)) return;

    final target = _bestAutoMoveTarget(fromCol, fromIdx);
    if (target == -1) return;

    final movingCards =
        List<PlayingCard>.from(state.tableau[fromCol].sublist(fromIdx));
    _performMoveWithAnimation(fromCol, fromIdx, target, movingCards);
  }

  /// Picks the auto-move target for the group at (fromCol, fromIdx).
  ///
  /// Priority order:
  ///   1. A column whose bottom card has the same suit as the moved card.
  ///      Among these, prefer the longest existing same-suit streak.
  ///   2. A non-empty column with a different-suit bottom. Same tiebreak.
  ///   3. The leftmost empty column.
  ///
  /// Within each tier, ties go to the leftmost column (we only replace
  /// on strict improvement and iterate left-to-right).
  int _bestAutoMoveTarget(int fromCol, int fromIdx) {
    final src = state.tableau[fromCol][fromIdx];

    int bestSameSuit = -1;
    int bestSameSuitStreak = -1;
    int bestDiffSuit = -1;
    int bestDiffSuitStreak = -1;
    int bestEmpty = -1;

    for (var c = 0; c < 10; c++) {
      if (!state.canDropOn(fromCol, fromIdx, c)) continue;
      final col = state.tableau[c];

      if (col.isEmpty) {
        if (bestEmpty == -1) bestEmpty = c;
        continue;
      }

      final streak = _bottomSameSuitStreak(c);
      if (col.last.suit == src.suit) {
        if (streak > bestSameSuitStreak) {
          bestSameSuit = c;
          bestSameSuitStreak = streak;
        }
      } else {
        if (streak > bestDiffSuitStreak) {
          bestDiffSuit = c;
          bestDiffSuitStreak = streak;
        }
      }
    }

    if (bestSameSuit != -1) return bestSameSuit;
    if (bestDiffSuit != -1) return bestDiffSuit;
    return bestEmpty;
  }

  int _bottomSameSuitStreak(int col) {
    final cards = state.tableau[col];
    if (cards.isEmpty) return 0;
    if (!cards.last.faceUp) return 0;
    var len = 1;
    final suit = cards.last.suit;
    var prev = cards.last.rank.value;
    for (var i = cards.length - 2; i >= 0; i--) {
      final c = cards[i];
      if (!c.faceUp || c.suit != suit || c.rank.value != prev + 1) break;
      prev = c.rank.value;
      len++;
    }
    return len;
  }

  /// Drives the central animated move pipeline: snapshot for undo, mutate
  /// state without auto-collect, animate the cards into the target column,
  /// then run the foundation collection step (also animated) before
  /// settling. Used by both drag-drop and auto-move.
  Future<void> _performMoveWithAnimation(
    int fromCol,
    int fromIdx,
    int toCol,
    List<PlayingCard> movingCards,
  ) async {
    _undoStack.add(state.snapshot());
    _clearHint();

    state.moveGroup(fromCol, fromIdx, toCol, autoCollect: false);
    onChanged?.call();
    _animating = true;

    await _animateCardsToFinalPositions(movingCards, 0.22, 0.025);

    final runs = state.collectCompletedRuns();
    if (runs.isNotEmpty) {
      await _animateRunsToFoundations(runs);
      onChanged?.call();
    }

    _animating = false;
    _relayout();
    _checkWin();
    _checkGameOver();
  }

  /// Captures the current visual positions of [cards], runs `_relayout`
  /// to compute their final positions, then animates each from its old
  /// position to the freshly-computed target.
  Future<void> _animateCardsToFinalPositions(
    List<PlayingCard> cards,
    double duration,
    double stagger,
  ) async {
    final origins = <PlayingCard, Vector2>{
      for (final c in cards) c: _byCard[c]!.position.clone(),
    };
    _relayout();
    final targets = <PlayingCard, Vector2>{
      for (final c in cards) c: _byCard[c]!.position.clone(),
    };
    // Restore starts so MoveToEffect can play from origin → target.
    for (final c in cards) {
      _byCard[c]!.position = origins[c]!;
    }

    final futures = <async.Completer<void>>[];
    var delay = 0.0;
    for (var i = 0; i < cards.length; i++) {
      final comp = _byCard[cards[i]]!;
      comp.priority = 8000 + i;
      final completer = async.Completer<void>();
      futures.add(completer);
      comp.add(MoveToEffect(
        targets[cards[i]]!,
        EffectController(duration: duration, startDelay: delay),
        onComplete: completer.complete,
      ));
      delay += stagger;
    }
    await Future.wait(futures.map((c) => c.future));
  }

  /// Animates the cards in each completed run sliding from their current
  /// tableau positions to the matching foundation slot with a staggered
  /// cascade. Cards in `run.cards` are in K→A order.
  Future<void> _animateRunsToFoundations(List<CompletedRun> runs) async {
    final futures = <async.Completer<void>>[];
    for (final run in runs) {
      final fnPos = _foundationSlot(run.foundationSlot);
      var delay = 0.0;
      for (var i = 0; i < run.cards.length; i++) {
        final comp = _byCard[run.cards[i]]!;
        comp.priority = 12000 + run.foundationSlot * 100 + i;
        final completer = async.Completer<void>();
        futures.add(completer);
        comp.add(MoveToEffect(
          fnPos,
          EffectController(duration: 0.32, startDelay: delay),
          onComplete: completer.complete,
        ));
        delay += 0.05;
      }
    }
    await Future.wait(futures.map((c) => c.future));
  }

  /// Finds the best move to highlight.
  ///
  /// Outcome:
  ///   • A meaningful move exists → highlight the source card group and
  ///     return [HintResult.shown].
  ///   • No meaningful move but the stock has cards → highlight the
  ///     stock pile and return [HintResult.dealFromStock].
  ///   • No meaningful move, stock empty, but a legal *setup* move
  ///     exists (one that exposes a meaningful follow-up after a 1-ply
  ///     lookahead — e.g. drop 4♠ onto an empty column so the 5♥ above
  ///     can move next turn and reveal a face-down) → highlight that
  ///     move and still return [HintResult.shown].
  ///   • Neither a meaningful move nor a setup move exists and the
  ///     stock is empty → return [HintResult.gameOver]. Pure
  ///     card-shuffling between empty columns lives here, since no
  ///     amount of shuffling exposes a meaningful follow-up.
  HintResult showHint() {
    _clearHint();
    if (_animating) return HintResult.busy;
    final best = _findBestMeaningfulMove();
    if (best != null) {
      _highlightMove(best);
      _hintTimer = async.Timer(const Duration(seconds: 2), _clearHint);
      // Only the meaningful outcomes (shown / dealFromStock) cost the
      // player score — `busy` and `gameOver` don't give them anything
      // actionable, so charging them feels punitive.
      state.applyHintPenalty();
      onChanged?.call();
      return HintResult.shown;
    }
    if (state.stock.isNotEmpty) {
      _stockArea.hinted = true;
      _hintTimer = async.Timer(const Duration(seconds: 2), _clearHint);
      state.applyHintPenalty();
      onChanged?.call();
      return HintResult.dealFromStock;
    }
    // Last resort: a "setup" move that doesn't advance the board on
    // its own but exposes a meaningful follow-up one move later.
    // Crucially this rejects pure cycling (e.g. K♠ bouncing between
    // two empty columns) because no future-state from those moves has
    // a meaningful move either.
    final setup = _findLegalSetupMove();
    if (setup != null) {
      _highlightMove(setup);
      _hintTimer = async.Timer(const Duration(seconds: 2), _clearHint);
      state.applyHintPenalty();
      onChanged?.call();
      return HintResult.shown;
    }
    return HintResult.gameOver;
  }

  /// Returns true if at least one legal move on the board would advance
  /// play (reveal a face-down card, empty a column onto a non-empty
  /// target, or grow the longest same-suit run).
  bool hasAdvancingMove() => _findBestMeaningfulMove() != null;

  /// True when the player is truly stuck — no path to making progress
  /// (now or one move out) AND no stock left to deal. Win-state is not
  /// considered game over here.
  ///
  /// "Path to progress" means either a meaningful move is available
  /// right now, or some legal setup move would expose a meaningful
  /// follow-up. Pure shuffles between empty columns aren't a path —
  /// they leave the board in an equivalent position.
  bool get isGameOver =>
      state.stock.isEmpty &&
      _findBestMeaningfulMove() == null &&
      _findLegalSetupMove() == null;

  _HintMove? _findBestMeaningfulMove() {
    _HintMove? bestMeaningful;
    int? bestScore;
    for (var fc = 0; fc < 10; fc++) {
      final col = state.tableau[fc];
      for (var i = 0; i < col.length; i++) {
        if (!state.isMovableGroup(fc, i)) continue;
        for (var tc = 0; tc < 10; tc++) {
          if (fc == tc) continue;
          if (!state.canDropOn(fc, i, tc)) continue;
          final int? score = _scoreHint(fc, i, tc);
          if (score == null) continue;
          final int? current = bestScore;
          if (current == null || score > current) {
            bestScore = score;
            bestMeaningful = _HintMove(fc, i, tc);
          }
        }
      }
    }
    return bestMeaningful;
  }

  /// One-ply lookahead: returns the leftmost-source legal move that
  /// **after being applied** would expose at least one meaningful
  /// move. Null if no such setup move exists.
  ///
  /// This is the discriminator between the previously broken extremes:
  ///   - "meaningful now" missed two-step progress like
  ///     `[face-down, 5♥, 4♠] + empty column`, where moving 4♠ to the
  ///     empty enables 5♥ → 4♠ next turn (which reveals the face-down).
  ///   - "any legal move" accepted pure cycling between empty columns
  ///     as still-playable when it's a clear stalemate — every reachable
  ///     state from such moves also has no meaningful follow-up.
  ///
  /// Simulates each candidate move via [SpiderGameState.snapshot] /
  /// [SpiderGameState.restore]; `autoCollect: false` so the simulation
  /// doesn't kick foundation-collection side effects we'd then have to
  /// roll back.
  _HintMove? _findLegalSetupMove() {
    for (var fc = 0; fc < 10; fc++) {
      final col = state.tableau[fc];
      for (var i = 0; i < col.length; i++) {
        if (!state.isMovableGroup(fc, i)) continue;
        for (var tc = 0; tc < 10; tc++) {
          if (fc == tc) continue;
          if (!state.canDropOn(fc, i, tc)) continue;
          final snap = state.snapshot();
          state.moveGroup(fc, i, tc, autoCollect: false);
          final next = _findBestMeaningfulMove();
          state.restore(snap);
          if (next != null) return _HintMove(fc, i, tc);
        }
      }
    }
    return null;
  }

  /// Marks the source card group of [move] as hinted so the view layer
  /// paints the highlight halo. Used by both the meaningful-hint and
  /// last-resort-hint paths.
  void _highlightMove(_HintMove move) {
    final cards = state.tableau[move.fromCol].sublist(move.fromIdx);
    for (final card in cards) {
      _byCard[card]?.hinted = true;
    }
  }

  /// Fires [onGameOver] if we've reached a stuck state. Should be called
  /// only after move/deal animations have settled so we don't fire while
  /// foundation runs are still being collected.
  void _checkGameOver() {
    if (state.isWon) return;
    if (onGameOver == null) return;
    if (isGameOver) onGameOver!.call();
  }

  void _clearHint() {
    _hintTimer?.cancel();
    _hintTimer = null;
    for (final c in _byCard.values) {
      c.hinted = false;
    }
    _stockArea.hinted = false;
  }

  /// Public wrapper around the private hint-scoring logic so unit tests
  /// can exercise it directly. Returns null for unmeaningful moves.
  @visibleForTesting
  int? scoreHintForTest(int fromCol, int fromIdx, int toCol) =>
      _scoreHint(fromCol, fromIdx, toCol);

  /// Heuristic score for a hint candidate, or null if the move doesn't
  /// actually advance the game.
  ///
  /// A move is considered meaningful iff at least one of these holds:
  ///   • It reveals a face-down card in the source column.
  ///   • It empties the source column onto a non-empty target.
  ///   • It makes the longest same-suit descending run in the two
  ///     affected columns *strictly longer* than it was before.
  ///
  /// The third clause is the fix for the "just shuffling cards" case:
  /// moving a same-suit group onto a same-suit target only counts when
  /// the merged run is bigger than any run that existed before — moves
  /// that just relocate a run from one column to another return null.
  int? _scoreHint(int fromCol, int fromIdx, int toCol) {
    final srcCol = state.tableau[fromCol];
    final src = srcCol[fromIdx];
    final tgt = state.tableau[toCol];

    final revealsFaceDown =
        fromIdx > 0 && !srcCol[fromIdx - 1].faceUp;
    final emptiesSource = fromIdx == 0 && tgt.isNotEmpty;

    // Same-suit run lengths on the two affected columns, before and after.
    final groupLen = srcCol.length - fromIdx;
    final beforeSrcRun = _bottomSameSuitStreak(fromCol);
    final beforeDstRun = _bottomSameSuitStreak(toCol);
    final beforeMax =
        beforeSrcRun > beforeDstRun ? beforeSrcRun : beforeDstRun;

    final dstMatchesSuit = tgt.isNotEmpty && tgt.last.suit == src.suit;
    final newDstRun = dstMatchesSuit ? beforeDstRun + groupLen : groupLen;
    final newSrcRun = _runLengthAfterRemovingTail(fromCol, fromIdx);
    final afterMax = newSrcRun > newDstRun ? newSrcRun : newDstRun;
    final lengthensRun = afterMax > beforeMax;

    if (!revealsFaceDown && !emptiesSource && !lengthensRun) return null;

    var score = 0;
    if (revealsFaceDown) score += 100;
    if (emptiesSource) score += 50;
    if (lengthensRun) score += 60 + (afterMax - beforeMax) * 10;
    // Completing a K→A run ships it straight to a foundation slot, which
    // is the single best thing a move can do.
    if (newDstRun >= 13) score += 500;
    return score;
  }

  /// Same-suit descending run length at the new bottom of [col] after
  /// removing every card from [fromIdx] onward, treating any newly
  /// exposed card as face-up (the game auto-flips it on move).
  int _runLengthAfterRemovingTail(int col, int fromIdx) {
    final cards = state.tableau[col];
    if (fromIdx == 0) return 0;
    var len = 1;
    final suit = cards[fromIdx - 1].suit;
    var prev = cards[fromIdx - 1].rank.value;
    for (var i = fromIdx - 2; i >= 0; i--) {
      final c = cards[i];
      if (!c.faceUp || c.suit != suit || c.rank.value != prev + 1) break;
      prev = c.rank.value;
      len++;
    }
    return len;
  }

  void _rebuildAll({bool animateInitialDeal = false}) {
    for (final c in _byCard.values) {
      c.removeFromParent();
    }
    _byCard.clear();
    _dragGroup.clear();

    void register(PlayingCard card) {
      final comp = CardComponent(card: card, game: this);
      _byCard[card] = comp;
      world.add(comp);
    }

    for (final col in state.tableau) {
      for (final card in col) {
        register(card);
      }
    }
    for (final card in state.stock) {
      register(card);
    }
    for (final pile in state.foundations) {
      for (final card in pile) {
        register(card);
      }
    }

    if (animateInitialDeal) {
      _animateInitialDeal();
    } else {
      _relayout();
    }
  }

  /// Starts every tableau card face-down at the stock origin, then moves
  /// each one to its column with a staggered delay. The bottom card of
  /// every column flips face-up when it arrives.
  ///
  /// We wait on the actual effect-completion callbacks (via Completers)
  /// rather than a wall-clock Future.delayed. Wall-clock timing isn't
  /// safe on Flutter web — frame rate is uneven during the engine's
  /// warm-up, so an effect's onComplete can fire later than the same
  /// duration would predict on native. Waiting on completers guarantees
  /// `_animating` stays true until every card has actually finished
  /// flipping face-up, which is what hint detection relies on.
  Future<void> _animateInitialDeal() async {
    _animating = true;

    final stockPos = _stockPos();
    for (var i = 0; i < state.stock.length; i++) {
      final comp = _byCard[state.stock[i]]!;
      comp.column = -1;
      comp.position = stockPos + Vector2(-i * 0.4, -i * 0.4);
      comp.priority = i + 1;
    }
    _stockArea.priority = state.stock.length + 1;

    // Capture final face-up state, force everything face-down for the deal.
    final targetFaceUp = <PlayingCard, bool>{};
    for (final col in state.tableau) {
      for (final card in col) {
        targetFaceUp[card] = card.faceUp;
        card.faceUp = false;
      }
    }

    const moveDuration = 0.18;
    const perCardDelay = 0.020;
    var stagger = 0.0;
    final completers = <async.Completer<void>>[];

    for (var col = 0; col < state.tableau.length; col++) {
      final cards = state.tableau[col];
      final origin = _columnOrigin(col);
      var y = origin.y;
      for (var i = 0; i < cards.length; i++) {
        final card = cards[i];
        final comp = _byCard[card]!;
        comp.column = col;
        comp.indexInColumn = i;
        comp.position = stockPos.clone();
        comp.priority = 10000 + (col * 20) + i;
        final target = Vector2(origin.x, y);
        final shouldFlip = targetFaceUp[card] == true;
        final completer = async.Completer<void>();
        completers.add(completer);
        comp.add(MoveToEffect(
          target,
          EffectController(duration: moveDuration, startDelay: stagger),
          onComplete: () {
            if (shouldFlip) card.faceUp = true;
            completer.complete();
          },
        ));
        y += GameLayout.faceDownFan;
        stagger += perCardDelay;
      }
    }

    try {
      await Future.wait(completers.map((c) => c.future));
    } finally {
      // Defensive: guarantee every card that should be face-up at the end
      // of the deal actually is. On dart2js, the microtask ordering
      // between Flame's effect onComplete callbacks and our completers
      // can let Future.wait resolve before every flip has been applied,
      // which leaves some bottom cards stuck face-down and breaks the
      // hint logic (no movable groups, no face-down to reveal, etc.).
      targetFaceUp.forEach((card, shouldFlip) {
        if (shouldFlip) card.faceUp = true;
      });
      _animating = false;
      _relayout();
    }
  }

  /// Maximum vertical span a tableau column can occupy before its bottom
  /// card would start overlapping the foundation row. Card height is
  /// reserved for the bottom card itself; the spans we compress live
  /// strictly between cards.
  double get _maxColumnSpan {
    return _foundationSlot(0).y -
        GameLayout.tableauTop -
        GameLayout.cardHeight -
        12; // breathing room above the foundation outlines
  }

  /// Returns the (faceUp, faceDown) fan offsets to use for a column,
  /// scaled uniformly down from the defaults when the natural span would
  /// overflow the available height. Floors keep the corner indices
  /// readable when many cards stack up.
  ({double faceUp, double faceDown}) _columnFans(List<PlayingCard> cards) {
    const minFaceUpFan = 14.0;
    const minFaceDownFan = 5.0;

    var faceUp = GameLayout.faceUpFan.toDouble();
    var faceDown = GameLayout.faceDownFan.toDouble();
    if (cards.length <= 1) return (faceUp: faceUp, faceDown: faceDown);

    var span = 0.0;
    for (var i = 0; i < cards.length - 1; i++) {
      span += cards[i].faceUp ? faceUp : faceDown;
    }
    final available = _maxColumnSpan;
    if (span <= available) return (faceUp: faceUp, faceDown: faceDown);

    final scale = available / span;
    final compressedUp = (faceUp * scale).clamp(minFaceUpFan, faceUp);
    final compressedDown = (faceDown * scale).clamp(minFaceDownFan, faceDown);
    return (faceUp: compressedUp, faceDown: compressedDown);
  }

  /// Resolved vertical position for each card in column [col], using
  /// compressed fans if the column would otherwise overflow.
  List<Vector2> _columnCardPositions(int col) {
    final cards = state.tableau[col];
    final fans = _columnFans(cards);
    final origin = _columnOrigin(col);
    final positions = <Vector2>[];
    var y = origin.y;
    for (var i = 0; i < cards.length; i++) {
      positions.add(Vector2(origin.x, y));
      if (i < cards.length - 1) {
        y += cards[i].faceUp ? fans.faceUp : fans.faceDown;
      }
    }
    return positions;
  }

  void _relayout() {
    for (var col = 0; col < state.tableau.length; col++) {
      final cards = state.tableau[col];
      final positions = _columnCardPositions(col);
      for (var i = 0; i < cards.length; i++) {
        final comp = _byCard[cards[i]]!;
        comp.column = col;
        comp.indexInColumn = i;
        comp.position = positions[i];
        comp.priority = i + 1;
      }
    }

    // Stock: all cards share the stock outline position; only the top
    // card is visible since they're all face-down with the same back.
    final stockPos = _stockPos();
    for (var i = 0; i < state.stock.length; i++) {
      final comp = _byCard[state.stock[i]]!;
      comp.column = -1;
      comp.indexInColumn = -1;
      comp.position = stockPos;
      comp.priority = i + 1;
    }
    _stockArea.priority = state.stock.length + 1;

    // Foundations: same idea — every card in a completed run sits at the
    // foundation slot. The top card (the Ace) is what the player sees.
    for (var f = 0; f < state.foundations.length; f++) {
      final pile = state.foundations[f];
      final pos = _foundationSlot(f);
      for (var i = 0; i < pile.length; i++) {
        final comp = _byCard[pile[i]]!;
        comp.column = -2;
        comp.indexInColumn = -1;
        comp.position = pos;
        comp.priority = i + 1;
      }
    }
  }

  /// Called by a CardComponent when the user starts a drag on it. Returns
  /// false if the card cannot lead a drag (e.g. mid-column non-runs).
  bool beginDrag(CardComponent head) {
    if (_animating) return false;
    final col = head.column;
    final idx = head.indexInColumn;
    if (col < 0) return false;
    if (!state.isMovableGroup(col, idx)) return false;
    _dragFromColumn = col;
    _dragFromIndex = idx;
    _dragGroup
      ..clear()
      ..addAll(state.tableau[col]
          .sublist(idx)
          .map((c) => _byCard[c]!));
    for (var i = 0; i < _dragGroup.length; i++) {
      _dragGroup[i].priority = 5000 + i;
    }
    return true;
  }

  void dragBy(Vector2 delta) {
    for (final c in _dragGroup) {
      c.position += delta;
    }
  }

  void endDrag(Vector2 origin, {bool cancelled = false}) {
    if (_dragGroup.isEmpty) {
      _relayout();
      return;
    }
    var targetColumn = -1;
    if (!cancelled) {
      targetColumn = _hitColumn(_dragGroup.first.position);
    }
    if (targetColumn >= 0 &&
        state.canDropOn(_dragFromColumn, _dragFromIndex, targetColumn)) {
      final fromCol = _dragFromColumn;
      final fromIdx = _dragFromIndex;
      final movingCards =
          _dragGroup.map((c) => c.card).toList(growable: false);
      _dragGroup.clear();
      _dragFromColumn = -1;
      _dragFromIndex = -1;
      _performMoveWithAnimation(fromCol, fromIdx, targetColumn, movingCards);
      return;
    }
    _dragGroup.clear();
    _dragFromColumn = -1;
    _dragFromIndex = -1;
    _relayout();
  }

  /// Determines which tableau column a dropped card's top-left lands in.
  int _hitColumn(Vector2 topLeft) {
    final cardCentreX = topLeft.x + GameLayout.cardWidth / 2;
    var best = -1;
    var bestDx = double.infinity;
    for (var col = 0; col < 10; col++) {
      final origin = _columnOrigin(col);
      final centre = origin.x + GameLayout.cardWidth / 2;
      final dx = (centre - cardCentreX).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = col;
      }
    }
    // Require the drop to overlap the chosen column horizontally.
    if (bestDx > GameLayout.cardWidth) return -1;
    return best;
  }

  void dealFromStock() {
    if (_animating) return;
    if (!state.canDealFromStock) return;
    _clearHint();
    _undoStack.add(state.snapshot());
    final dealtCards = <PlayingCard>[];
    for (var i = 0; i < 10 && i < state.stock.length; i++) {
      dealtCards.add(state.stock[state.stock.length - 1 - i]);
    }
    state.dealFromStock(autoCollect: false);
    onChanged?.call();
    _runStockDealAnimation(dealtCards);
  }

  Future<void> _runStockDealAnimation(List<PlayingCard> dealt) async {
    _animating = true;
    const moveDuration = 0.20;
    const perCardDelay = 0.045;
    var stagger = 0.0;
    final futures = <async.Completer<void>>[];

    for (var col = 0; col < dealt.length && col < 10; col++) {
      final card = dealt[col];
      final comp = _byCard[card]!;
      final cards = state.tableau[col];
      // Compute the new card's target via the column-position helper so
      // it honours fan compression — same source of truth as _relayout.
      final positions = _columnCardPositions(col);
      final target = positions.last;
      comp.column = col;
      comp.indexInColumn = cards.length - 1;
      comp.priority = 10000 + col;
      card.faceUp = false;
      comp.position = _stockPos();
      final completer = async.Completer<void>();
      futures.add(completer);
      comp.add(MoveToEffect(
        target,
        EffectController(duration: moveDuration, startDelay: stagger),
        onComplete: () {
          card.faceUp = true;
          completer.complete();
        },
      ));
      stagger += perCardDelay;
    }
    await Future.wait(futures.map((c) => c.future));

    // Defensive: on dart2js the microtask scheduling between Flame's
    // MoveToEffect.onComplete callbacks and our completers can let
    // Future.wait resolve before every onComplete has set faceUp=true.
    // That leaves some freshly-dealt bottom cards stuck face-down, which
    // makes isMovableGroup reject them, makes hasAdvancingMove return
    // false, and — if this was the last deal so the stock is now empty —
    // fires a bogus "Game Over" dialog. Forcing faceUp=true here closes
    // the race regardless of callback ordering.
    for (final card in dealt) {
      card.faceUp = true;
    }

    final runs = state.collectCompletedRuns();
    if (runs.isNotEmpty) {
      await _animateRunsToFoundations(runs);
      onChanged?.call();
    }

    _animating = false;
    _relayout();
    _checkWin();
    _checkGameOver();
  }

  void _checkWin() {
    if (state.isWon) {
      onWon?.call(state.finalScore, state.elapsedSeconds, state.moves);
    }
  }

  @override
  void onRemove() {
    _hintTimer?.cancel();
    super.onRemove();
  }
}

class _HintMove {
  _HintMove(this.fromCol, this.fromIdx, this.toCol);
  final int fromCol;
  final int fromIdx;
  final int toCol;
}

RRect _slotRRect(Vector2 size) => RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(12),
    );

/// Outline for an empty tableau column.
class _ColumnSlot extends PositionComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      _slotRRect(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }
}

/// Outline for an empty foundation slot.
class _FoundationComponent extends PositionComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      _slotRRect(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.amber.withValues(alpha: 0.5),
    );
  }
}

/// Tap target for the stock pile.
class _StockComponent extends PositionComponent with TapCallbacks {
  _StockComponent({required this.game});

  final SpiderGame game;

  /// When true, draws a yellow halo around the pile — used by the hint
  /// system to nudge the player toward dealing.
  bool hinted = false;

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isAnimating) return;
    game.dealFromStock();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      _slotRRect(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.4),
    );
    if (hinted) {
      canvas.drawRRect(
        _slotRRect(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD24A),
      );
    }
  }
}
