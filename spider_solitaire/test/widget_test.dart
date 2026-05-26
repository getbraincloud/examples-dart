import 'package:flutter_test/flutter_test.dart';
import 'package:spider_solitaire/game/spider_game.dart';
import 'package:spider_solitaire/models/card.dart';
import 'package:spider_solitaire/models/difficulty.dart';
import 'package:spider_solitaire/models/game_state.dart';
import 'package:spider_solitaire/models/scoring_config.dart';

void main() {
  group('SpiderGameState', () {
    test('1-suit deal produces 104 cards across tableau + stock', () {
      final s = SpiderGameState(difficulty: Difficulty.oneSuit, seed: 1);
      final tableauCount =
          s.tableau.fold<int>(0, (acc, c) => acc + c.length);
      expect(tableauCount + s.stock.length, 104);
      expect(tableauCount, 54);
      expect(s.stock.length, 50);
    });

    test('1-suit deck uses only spades', () {
      final s = SpiderGameState(difficulty: Difficulty.oneSuit, seed: 1);
      final all = [...s.stock, for (final c in s.tableau) ...c];
      expect(all.every((c) => c.suit == Suit.spades), isTrue);
    });

    test('4-suit deck uses all four suits twice', () {
      final s = SpiderGameState(difficulty: Difficulty.fourSuit, seed: 1);
      final all = [...s.stock, for (final c in s.tableau) ...c];
      for (final suit in Suit.values) {
        expect(all.where((c) => c.suit == suit).length, 26);
      }
    });

    test('top card of each column starts face-up', () {
      final s = SpiderGameState(difficulty: Difficulty.fourSuit, seed: 1);
      for (final col in s.tableau) {
        expect(col.last.faceUp, isTrue);
      }
    });

    test('hint scoring rewards a bottom-card move that reveals face-down', () {
      // Hand-craft a state: column 0 has [face-down, 7♠]; column 1 has
      // [face-down, 8♠]. Moving 7♠ from col 0 onto 8♠ on col 1 is the
      // canonical "right after a deal" hint: reveals a face-down, joins
      // the same suit.
      final s = SpiderGameState(difficulty: Difficulty.oneSuit, seed: 1);
      // Wipe and rebuild a controlled tiny board.
      for (final col in s.tableau) {
        col.clear();
      }
      s.tableau[0].add(PlayingCard(suit: Suit.spades, rank: Rank.king));
      s.tableau[0].add(
        PlayingCard(suit: Suit.spades, rank: Rank.seven, faceUp: true),
      );
      s.tableau[1].add(PlayingCard(suit: Suit.spades, rank: Rank.king));
      s.tableau[1].add(
        PlayingCard(suit: Suit.spades, rank: Rank.eight, faceUp: true),
      );

      final game = SpiderGame(difficulty: Difficulty.oneSuit, seed: 1);
      // Replace the auto-generated state with our crafted one. We don't
      // load the FlameGame's components since we're only exercising
      // scoreHintForTest, which reads from `state` directly.
      game.state = s;

      expect(s.isMovableGroup(0, 1), isTrue,
          reason: '7♠ at idx 1 of col 0 is a movable group of size 1');
      expect(s.canDropOn(0, 1, 1), isTrue,
          reason: '7♠ can drop onto 8♠');

      final score = game.scoreHintForTest(0, 1, 1);
      expect(score, isNotNull,
          reason: 'Move reveals a face-down card AND joins a same-suit '
              "run — that's the textbook 'meaningful' move.");
      expect(score!, greaterThan(0));
    });

    test('starting score matches ScoringConfig.scoreStart', () {
      final s = SpiderGameState(
        difficulty: Difficulty.oneSuit,
        seed: 1,
        scoring: const ScoringConfig(scoreStart: 5000),
      );
      expect(s.score, 5000);
    });

    test('per-move delta deducts from score', () {
      const cfg = ScoringConfig(scoreStart: 1000, scoreMove: -10);
      final s = SpiderGameState(
        difficulty: Difficulty.oneSuit,
        seed: 1,
        scoring: cfg,
      );
      // Find any legal move and apply it; only one move should fire.
      var moved = false;
      for (var fc = 0; fc < 10 && !moved; fc++) {
        for (var i = 0; i < s.tableau[fc].length && !moved; i++) {
          if (!s.isMovableGroup(fc, i)) continue;
          for (var tc = 0; tc < 10 && !moved; tc++) {
            if (s.canDropOn(fc, i, tc)) {
              s.moveGroup(fc, i, tc);
              moved = true;
            }
          }
        }
      }
      expect(moved, isTrue, reason: 'seed=1 deal should have at least 1 move');
      // Score may have moved by more than -10 if the move auto-collected
      // a run, but the floor it can hit is scoreMove from start.
      expect(s.score, lessThanOrEqualTo(cfg.scoreStart + cfg.scoreMove));
    });

    test('applyHintPenalty deducts scoreHint and bumps hintsUsed', () {
      const cfg = ScoringConfig(scoreStart: 5000, scoreHint: -15);
      final s = SpiderGameState(
        difficulty: Difficulty.oneSuit,
        seed: 1,
        scoring: cfg,
      );
      expect(s.hintsUsed, 0);
      expect(s.score, 5000);
      s.applyHintPenalty();
      expect(s.hintsUsed, 1);
      expect(s.score, 4985);
    });

    test('score never goes below zero on move/hint penalty', () {
      const cfg = ScoringConfig(scoreStart: 5, scoreMove: -10, scoreHint: -15);
      final s = SpiderGameState(
        difficulty: Difficulty.oneSuit,
        seed: 1,
        scoring: cfg,
      );
      s.applyHintPenalty();
      expect(s.score, 0);
    });
  });

  group('ScoringConfig', () {
    test('default values match the agreed spec', () {
      const cfg = ScoringConfig();
      expect(cfg.scoreStart, 5000);
      expect(cfg.scoreRunBase, 1495);
      expect(cfg.scoreMove, -10);
      expect(cfg.scoreHint, -15);
      expect(cfg.runMultiplierSuits1, 1);
      expect(cfg.runMultiplierSuits2, 2);
      expect(cfg.runMultiplierSuits4, 4);
    });

    test('runScoreFor scales by suit multiplier', () {
      const cfg = ScoringConfig();
      expect(cfg.runScoreFor(Difficulty.oneSuit), 1495);
      expect(cfg.runScoreFor(Difficulty.twoSuit), 1495 * 2);
      expect(cfg.runScoreFor(Difficulty.fourSuit), 1495 * 4);
    });

    test('withOverrides parses string values and ignores junk', () {
      const cfg = ScoringConfig();
      final overridden = cfg.withOverrides({
        'scoreStart': '7500',
        'scoreMove': '-25',
        'runMultiplierSuits4': '6',
        'runMultiplierSuits2': 'not a number',
      });
      expect(overridden.scoreStart, 7500);
      expect(overridden.scoreMove, -25);
      expect(overridden.runMultiplierSuits4, 6);
      // Unparseable values keep the default.
      expect(overridden.runMultiplierSuits2, cfg.runMultiplierSuits2);
      // Unmentioned keys keep the default.
      expect(overridden.scoreHint, cfg.scoreHint);
    });
  });

  group('SpiderGameState extras', () {
    test('snapshot + restore round-trips state', () {
      final s = SpiderGameState(difficulty: Difficulty.oneSuit, seed: 9);
      final before = s.snapshot();
      // Try to perform any one move; if none is legal, just restore unchanged.
      var moved = false;
      for (var fc = 0; fc < 10 && !moved; fc++) {
        for (var i = 0; i < s.tableau[fc].length && !moved; i++) {
          if (!s.isMovableGroup(fc, i)) continue;
          for (var tc = 0; tc < 10 && !moved; tc++) {
            if (s.canDropOn(fc, i, tc)) {
              s.moveGroup(fc, i, tc);
              moved = true;
            }
          }
        }
      }
      s.restore(before);
      expect(s.score, const ScoringConfig().scoreStart);
      expect(s.moves, 0);
      expect(s.stock.length, 50);
      for (var i = 0; i < 10; i++) {
        expect(s.tableau[i].length, i < 4 ? 6 : 5);
      }
    });
  });
}
