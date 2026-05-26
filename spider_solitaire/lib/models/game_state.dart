import 'dart:math';

import 'card.dart';
import 'difficulty.dart';
import 'scoring_config.dart';

/// Pure-Dart game state for Spider Solitaire.
///
/// Holds the ten tableau columns, the stock, the eight foundation piles
/// and the running score / move count. All rule enforcement happens here
/// — the Flame layer is purely a view + input source.
class SpiderGameState {
  SpiderGameState({
    required this.difficulty,
    int? seed,
    ScoringConfig? scoring,
  })  : scoring = scoring ?? const ScoringConfig(),
        _random = Random(seed) {
    _newGame();
  }

  final Difficulty difficulty;

  /// Tunable scoring weights. Captured at construction so a config
  /// reload from brainCloud doesn't change the rules mid-game.
  final ScoringConfig scoring;

  final Random _random;

  /// 10 tableau columns, bottom card is the "playable" end (last index).
  final List<List<PlayingCard>> tableau =
      List.generate(10, (_) => <PlayingCard>[], growable: false);

  /// Stock — drawn in 5 batches of 10 (one card to each column per draw).
  final List<PlayingCard> stock = <PlayingCard>[];

  /// 8 foundation slots. Each holds a completed K→A run.
  final List<List<PlayingCard>> foundations =
      List.generate(8, (_) => <PlayingCard>[], growable: false);

  /// Live score. Initialized from [ScoringConfig.scoreStart] in [_newGame].
  int score = 0;
  int moves = 0;

  /// Number of hint requests the player has actually consumed this
  /// game (i.e. ones that resulted in something useful — not the
  /// "game over" or "busy" outcomes).
  int hintsUsed = 0;
  DateTime? startedAt;

  bool get isWon => foundations.every((f) => f.length == 13);

  /// Index of the next empty foundation slot, or -1 if all are used.
  int get _nextFoundationIndex => foundations.indexWhere((f) => f.isEmpty);

  void _newGame() {
    for (final col in tableau) {
      col.clear();
    }
    for (final f in foundations) {
      f.clear();
    }
    stock.clear();
    score = scoring.scoreStart;
    moves = 0;
    hintsUsed = 0;

    final deck = _buildDeck();
    deck.shuffle(_random);

    // Deal 54 cards: first 4 columns get 6 cards, next 6 get 5.
    var i = 0;
    for (var col = 0; col < 10; col++) {
      final count = col < 4 ? 6 : 5;
      for (var c = 0; c < count; c++) {
        tableau[col].add(deck[i++]);
      }
      tableau[col].last.faceUp = true;
    }

    // Remaining 50 cards form the stock.
    stock.addAll(deck.sublist(i));
    startedAt = DateTime.now();
  }

  List<PlayingCard> _buildDeck() {
    final cards = <PlayingCard>[];
    final suitsByDifficulty = <Difficulty, List<Suit>>{
      Difficulty.oneSuit: const [Suit.spades],
      Difficulty.twoSuit: const [Suit.spades, Suit.hearts],
      Difficulty.fourSuit: Suit.values,
    };
    final suits = suitsByDifficulty[difficulty]!;
    final copies = 104 ~/ (suits.length * 13);
    for (var s = 0; s < suits.length; s++) {
      for (var c = 0; c < copies; c++) {
        for (final rank in Rank.all) {
          cards.add(PlayingCard(suit: suits[s], rank: rank));
        }
      }
    }
    return cards;
  }

  int get elapsedSeconds {
    if (startedAt == null) return 0;
    return DateTime.now().difference(startedAt!).inSeconds;
  }

  /// Result returned to the GameResult sent to brainCloud on win.
  /// Higher is better.
  int get finalScore => score;

  /// Captures a structural snapshot suitable for undo. Card objects are
  /// shared by reference; only the face-up state is preserved per card.
  GameSnapshot snapshot() => GameSnapshot._capture(this);

  /// Restores a previously captured snapshot in place.
  void restore(GameSnapshot snap) => snap._restoreTo(this);

  // ---- Rules ----

  /// Cards from [fromColumn] starting at [fromIndex] form a movable group
  /// when: all are face-up, all share a suit, and ranks descend by 1.
  bool isMovableGroup(int fromColumn, int fromIndex) {
    final col = tableau[fromColumn];
    if (fromIndex < 0 || fromIndex >= col.length) return false;
    for (var i = fromIndex; i < col.length; i++) {
      if (!col[i].faceUp) return false;
    }
    final suit = col[fromIndex].suit;
    var prev = col[fromIndex].rank.value;
    for (var i = fromIndex + 1; i < col.length; i++) {
      if (col[i].suit != suit) return false;
      if (col[i].rank.value != prev - 1) return false;
      prev = col[i].rank.value;
    }
    return true;
  }

  /// May the group at [fromColumn]/[fromIndex] be placed onto [toColumn]?
  /// Spider accepts any descending placement regardless of suit — suit
  /// only matters for moving multi-card groups out of a column.
  bool canDropOn(int fromColumn, int fromIndex, int toColumn) {
    if (fromColumn == toColumn) return false;
    if (!isMovableGroup(fromColumn, fromIndex)) return false;
    final src = tableau[fromColumn][fromIndex];
    final dst = tableau[toColumn];
    if (dst.isEmpty) return true;
    final top = dst.last;
    return top.faceUp && top.rank.value == src.rank.value + 1;
  }

  /// Perform the move. Returns true on success.
  ///
  /// When [autoCollect] is true (default), any K→A same-suit run that
  /// lands at the bottom of a column is shipped to a foundation slot in
  /// the same call. Pass false when the caller wants to animate the move
  /// before the foundation shipment.
  bool moveGroup(int fromColumn, int fromIndex, int toColumn,
      {bool autoCollect = true}) {
    if (!canDropOn(fromColumn, fromIndex, toColumn)) return false;
    final src = tableau[fromColumn];
    final moved = src.sublist(fromIndex);
    src.removeRange(fromIndex, src.length);
    tableau[toColumn].addAll(moved);
    if (src.isNotEmpty && !src.last.faceUp) {
      src.last.faceUp = true;
    }
    moves++;
    score = max(0, score + scoring.scoreMove);
    if (autoCollect) collectCompletedRuns();
    return true;
  }

  /// Records a hint that the engine acted on, applying the
  /// [ScoringConfig.scoreHint] penalty. Called by the view layer (the
  /// engine doesn't draw hints itself).
  void applyHintPenalty() {
    hintsUsed++;
    score = max(0, score + scoring.scoreHint);
  }

  /// Ships any complete K→A same-suit runs sitting at the bottom of
  /// tableau columns to the next available foundation slots. Returns
  /// the runs that were collected (with the cards in K→A order) so the
  /// caller can drive an animation.
  List<CompletedRun> collectCompletedRuns() {
    final results = <CompletedRun>[];
    for (final col in tableau) {
      if (col.length < 13) continue;
      final start = col.length - 13;
      final suit = col[start].suit;
      var ok = col[start].faceUp && col[start].rank.value == 13;
      if (ok) {
        for (var i = 0; i < 13 && ok; i++) {
          final c = col[start + i];
          if (!c.faceUp || c.suit != suit || c.rank.value != 13 - i) {
            ok = false;
          }
        }
      }
      if (ok) {
        final slot = _nextFoundationIndex;
        if (slot == -1) continue;
        final cards = col.sublist(start);
        foundations[slot] = cards;
        col.removeRange(start, col.length);
        if (col.isNotEmpty && !col.last.faceUp) {
          col.last.faceUp = true;
        }
        score += scoring.runScoreFor(difficulty);
        results.add(CompletedRun(slot, cards));
      }
    }
    return results;
  }

  /// Whether a stock deal is currently possible. Standard Spider rules
  /// forbid dealing while any column is empty; we relax that here so
  /// the user can always deal as long as the stock has cards.
  bool get canDealFromStock => stock.isNotEmpty;

  bool dealFromStock({bool autoCollect = true}) {
    if (!canDealFromStock) return false;
    for (var i = 0; i < 10 && stock.isNotEmpty; i++) {
      final card = stock.removeLast();
      card.faceUp = true;
      tableau[i].add(card);
    }
    moves++;
    score = max(0, score + scoring.scoreMove);
    if (autoCollect) collectCompletedRuns();
    return true;
  }
}

class CompletedRun {
  CompletedRun(this.foundationSlot, this.cards);
  final int foundationSlot;
  final List<PlayingCard> cards;
}

/// Immutable snapshot of a [SpiderGameState] used for undo.
class GameSnapshot {
  GameSnapshot._capture(SpiderGameState s)
      : tableau = s.tableau
            .map((c) => List<PlayingCard>.from(c))
            .toList(growable: false),
        stock = List<PlayingCard>.from(s.stock),
        foundations = s.foundations
            .map((c) => List<PlayingCard>.from(c))
            .toList(growable: false),
        faceUp = {
          for (final col in s.tableau)
            for (final card in col) card: card.faceUp,
          for (final card in s.stock) card: card.faceUp,
          for (final f in s.foundations)
            for (final card in f) card: card.faceUp,
        },
        score = s.score,
        moves = s.moves,
        hintsUsed = s.hintsUsed;

  final List<List<PlayingCard>> tableau;
  final List<PlayingCard> stock;
  final List<List<PlayingCard>> foundations;
  final Map<PlayingCard, bool> faceUp;
  final int score;
  final int moves;
  final int hintsUsed;

  void _restoreTo(SpiderGameState s) {
    for (var i = 0; i < s.tableau.length; i++) {
      s.tableau[i]
        ..clear()
        ..addAll(tableau[i]);
    }
    s.stock
      ..clear()
      ..addAll(stock);
    for (var i = 0; i < s.foundations.length; i++) {
      s.foundations[i] = List<PlayingCard>.from(foundations[i]);
    }
    faceUp.forEach((card, fu) => card.faceUp = fu);
    s.score = score;
    s.moves = moves;
    s.hintsUsed = hintsUsed;
  }
}
