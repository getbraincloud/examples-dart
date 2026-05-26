import '../config.dart';
import 'braincloud_service.dart';

/// Snapshot of the player statistics tracked by Spider Solitaire.
class PlayerStats {
  const PlayerStats({
    required this.gamesPlayed,
    required this.gamesWon,
    required this.currentWinStreak,
    required this.longestWinStreak,
    required this.highScore,
    required this.fastestTimeSeconds,
    required this.fewestMoves,
  });

  final int gamesPlayed;
  final int gamesWon;
  final int currentWinStreak;
  final int longestWinStreak;
  final int highScore;
  final int fastestTimeSeconds;
  final int fewestMoves;

  static const empty = PlayerStats(
    gamesPlayed: 0,
    gamesWon: 0,
    currentWinStreak: 0,
    longestWinStreak: 0,
    highScore: 0,
    fastestTimeSeconds: 0,
    fewestMoves: 0,
  );

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    int read(String key) {
      final v = map[key];
      if (v is num) return v.toInt();
      return 0;
    }

    return PlayerStats(
      gamesPlayed: read(StatKeys.gamesPlayed),
      gamesWon: read(StatKeys.gamesWon),
      currentWinStreak: read(StatKeys.currentWinStreak),
      longestWinStreak: read(StatKeys.longestWinStreak),
      highScore: read(StatKeys.highScore),
      fastestTimeSeconds: read(StatKeys.fastestTimeSeconds),
      fewestMoves: read(StatKeys.fewestMoves),
    );
  }
}

/// Outcome of a single game, used to update remote stats.
class GameResult {
  GameResult({
    required this.won,
    required this.score,
    required this.elapsedSeconds,
    required this.moves,
  });

  final bool won;
  final int score;
  final int elapsedSeconds;
  final int moves;
}

class StatsService {
  StatsService(this._bc);

  final BrainCloudService _bc;

  /// Returns the current stat snapshot for the authenticated user.
  Future<PlayerStats> fetch() async {
    final data = await _bc.readAllUserStats();
    final stats = data['statistics'];
    if (stats is Map<String, dynamic>) {
      return PlayerStats.fromMap(stats);
    }
    return PlayerStats.empty;
  }

  /// Apply a finished game's result to the player statistics.
  ///
  /// brainCloud's incrementUserStats only supports deltas, so for "best"
  /// values (high score, fastest time, fewest moves) we read the current
  /// value first and submit the delta needed to reach the new best.
  Future<PlayerStats> recordGameResult(GameResult result) async {
    final current = await fetch();
    final increments = <String, dynamic>{
      StatKeys.gamesPlayed: 1,
    };

    // High score is tracked regardless of win/loss — a player who
    // gives up after collecting a few foundations still earned those
    // points and should see them reflected in their personal best.
    if (result.score > current.highScore) {
      increments[StatKeys.highScore] = result.score - current.highScore;
    }

    if (result.won) {
      increments[StatKeys.gamesWon] = 1;
      increments[StatKeys.currentWinStreak] = 1;
      final newStreak = current.currentWinStreak + 1;
      if (newStreak > current.longestWinStreak) {
        increments[StatKeys.longestWinStreak] =
            newStreak - current.longestWinStreak;
      }
      // Fastest-time / fewest-moves only update on a completed game —
      // a 2-move abandoned round would otherwise set an unbeatable
      // "best" that no honest playthrough could match.
      if (current.fastestTimeSeconds == 0 ||
          result.elapsedSeconds < current.fastestTimeSeconds) {
        increments[StatKeys.fastestTimeSeconds] =
            result.elapsedSeconds - current.fastestTimeSeconds;
      }
      if (current.fewestMoves == 0 || result.moves < current.fewestMoves) {
        increments[StatKeys.fewestMoves] = result.moves - current.fewestMoves;
      }
    } else if (current.currentWinStreak > 0) {
      increments[StatKeys.currentWinStreak] = -current.currentWinStreak;
    }

    final data = await _bc.incrementUserStats(increments);
    final stats = data['statistics'];
    if (stats is Map<String, dynamic>) {
      return PlayerStats.fromMap(stats);
    }
    return fetch();
  }
}
