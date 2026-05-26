import 'difficulty.dart';

/// Tunable scoring weights for Spider Solitaire.
///
/// Defaults match the values baked into the game; production builds
/// override them by loading the matching brainCloud globalProperties at
/// startup and passing the resulting [ScoringConfig] into the engine.
///
/// All fields are `final` so a single instance can be shared across
/// games without risk of mid-session mutation.
class ScoringConfig {
  const ScoringConfig({
    this.scoreStart = 5000,
    this.scoreRunBase = 1495,
    this.scoreMove = -10,
    this.scoreHint = -15,
    this.runMultiplierSuits1 = 1,
    this.runMultiplierSuits2 = 2,
    this.runMultiplierSuits4 = 4,
  });

  /// Starting score for a fresh game.
  final int scoreStart;

  /// Base reward for completing a K→A run, before the suit multiplier.
  final int scoreRunBase;

  /// Per-move delta (typically negative). Applied for both card moves
  /// and stock deals.
  final int scoreMove;

  /// Per-hint delta (typically negative). Applied each time the player
  /// requests a hint that the engine can actually act on.
  final int scoreHint;

  /// Multiplier applied to [scoreRunBase] when a run is completed in
  /// 1-suit difficulty (easy). Broken out per difficulty so the weighting
  /// can be tuned independently from brainCloud globalProperties.
  final int runMultiplierSuits1;
  final int runMultiplierSuits2;
  final int runMultiplierSuits4;

  /// Reward for completing a K→A run at [difficulty]:
  /// [scoreRunBase] × multiplier-for-suit-count. Unknown suit counts
  /// fall back to the 1-suit multiplier so the game still scores.
  int runScoreFor(Difficulty difficulty) {
    switch (difficulty.suitCount) {
      case 1:
        return scoreRunBase * runMultiplierSuits1;
      case 2:
        return scoreRunBase * runMultiplierSuits2;
      case 4:
        return scoreRunBase * runMultiplierSuits4;
      default:
        return scoreRunBase * runMultiplierSuits1;
    }
  }

  /// brainCloud globalProperty keys used to override each field. These
  /// must match the property names created in the brainCloud portal
  /// under Design → Cloud Code → Global Properties.
  static const String keyScoreStart = 'scoreStart';
  static const String keyScoreRunBase = 'scoreRunBase';
  static const String keyScoreMove = 'scoreMove';
  static const String keyScoreHint = 'scoreHint';
  static const String keyRunMultiplierSuits1 = 'runMultiplierSuits1';
  static const String keyRunMultiplierSuits2 = 'runMultiplierSuits2';
  static const String keyRunMultiplierSuits4 = 'runMultiplierSuits4';

  /// All globalProperty keys this config reads. Passed verbatim to
  /// `globalAppService.readSelectedProperties` so brainCloud only sends
  /// back what we care about.
  static const List<String> allKeys = [
    keyScoreStart,
    keyScoreRunBase,
    keyScoreMove,
    keyScoreHint,
    keyRunMultiplierSuits1,
    keyRunMultiplierSuits2,
    keyRunMultiplierSuits4,
  ];

  /// Returns a new [ScoringConfig] with values from [props] layered on
  /// top of this one. Missing or unparseable keys keep the current
  /// value, so a partial server-side configuration is safe.
  ScoringConfig withOverrides(Map<String, String> props) {
    int pick(String key, int fallback) {
      final raw = props[key];
      if (raw == null) return fallback;
      return int.tryParse(raw.trim()) ?? fallback;
    }

    return ScoringConfig(
      scoreStart: pick(keyScoreStart, scoreStart),
      scoreRunBase: pick(keyScoreRunBase, scoreRunBase),
      scoreMove: pick(keyScoreMove, scoreMove),
      scoreHint: pick(keyScoreHint, scoreHint),
      runMultiplierSuits1: pick(keyRunMultiplierSuits1, runMultiplierSuits1),
      runMultiplierSuits2: pick(keyRunMultiplierSuits2, runMultiplierSuits2),
      runMultiplierSuits4: pick(keyRunMultiplierSuits4, runMultiplierSuits4),
    );
  }
}
