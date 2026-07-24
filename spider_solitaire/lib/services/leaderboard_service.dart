import 'package:braincloud/braincloud.dart';

import '../config.dart';
import '../models/difficulty.dart';
import 'braincloud_service.dart';

/// The metric a leaderboard tracks. Carries both the display sort
/// direction and the retention type — these MUST match (HIGH_TO_LOW
/// pairs with HIGH_VALUE; LOW_TO_HIGH pairs with LOW_VALUE) or scores
/// will look correct on read but get silently dropped on post.
enum LeaderboardMetric {
  highScore(
    'High Score',
    SortOrder.HIGH_TO_LOW,
    SocialLeaderboardType.HIGH_VALUE,
  ),
  fastestTime(
    'Fastest Time',
    SortOrder.LOW_TO_HIGH,
    SocialLeaderboardType.LOW_VALUE,
  ),
  fewestMoves(
    'Fewest Moves',
    SortOrder.LOW_TO_HIGH,
    SocialLeaderboardType.LOW_VALUE,
  );

  const LeaderboardMetric(this.label, this.sortOrder, this.leaderboardType);
  final String label;
  final SortOrder sortOrder;
  final SocialLeaderboardType leaderboardType;

  String leaderboardId(Difficulty difficulty) {
    switch (this) {
      case LeaderboardMetric.highScore:
        return LeaderboardIds.highScore(difficulty.suitCount);
      case LeaderboardMetric.fastestTime:
        return LeaderboardIds.fastestTime(difficulty.suitCount);
      case LeaderboardMetric.fewestMoves:
        return LeaderboardIds.fewestMoves(difficulty.suitCount);
    }
  }
}

/// One row on a leaderboard.
class LeaderboardEntry {
  LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.score,
    this.data,
  });

  final int rank;
  final String playerId;
  final String playerName;
  final int score;
  final Map<String, dynamic>? data;
}

class LeaderboardService {
  LeaderboardService(this._bc);

  final BrainCloudService _bc;

  /// Posts a high score (only) to the high-score leaderboard for
  /// [difficulty]. Used when the player abandons or gets stuck — the
  /// fastest-time / fewest-moves boards only make sense for completed
  /// games so we skip them and the player's partial score still gets
  /// onto the public ladder.
  Future<void> postHighScore({
    required Difficulty difficulty,
    required int score,
    required int elapsedSeconds,
    required int moves,
    String? playerName,
  }) async {
    final payload = <String, dynamic>{
      'score': score,
      'time': elapsedSeconds,
      'moves': moves,
      'suits': difficulty.suitCount,
      'completed': false,
      if (playerName != null && playerName.isNotEmpty)
        'playerName': playerName,
    };
    await _bc.postScore(
      leaderboardId: LeaderboardIds.highScore(difficulty.suitCount),
      score: score,
      leaderboardType: LeaderboardMetric.highScore.leaderboardType,
      data: payload,
    );
  }

  /// Posts a winning game to the three leaderboards for that difficulty.
  /// Time and move counts are submitted directly because brainCloud's
  /// LOW_TO_HIGH sort treats lower numbers as better.
  ///
  /// [playerName] is embedded in the score data so the leaderboard view
  /// can always display a name even if the player's profile name isn't
  /// populated server-side for some reason.
  Future<void> postWin({
    required Difficulty difficulty,
    required int score,
    required int elapsedSeconds,
    required int moves,
    String? playerName,
  }) async {
    final payload = <String, dynamic>{
      'score': score,
      'time': elapsedSeconds,
      'moves': moves,
      'suits': difficulty.suitCount,
      'completed': true,
      if (playerName != null && playerName.isNotEmpty)
        'playerName': playerName,
    };
    await Future.wait([
      _bc.postScore(
        leaderboardId: LeaderboardIds.highScore(difficulty.suitCount),
        score: score,
        leaderboardType: LeaderboardMetric.highScore.leaderboardType,
        data: payload,
      ),
      _bc.postScore(
        leaderboardId: LeaderboardIds.fastestTime(difficulty.suitCount),
        score: elapsedSeconds,
        leaderboardType: LeaderboardMetric.fastestTime.leaderboardType,
        data: payload,
      ),
      _bc.postScore(
        leaderboardId: LeaderboardIds.fewestMoves(difficulty.suitCount),
        score: moves,
        leaderboardType: LeaderboardMetric.fewestMoves.leaderboardType,
        data: payload,
      ),
    ]);
  }

  /// Fetches the top [limit] entries from one leaderboard.
  Future<List<LeaderboardEntry>> fetchTop({
    required Difficulty difficulty,
    required LeaderboardMetric metric,
    int limit = 50,
  }) async {
    final data = await _bc.getLeaderboardPage(
      leaderboardId: metric.leaderboardId(difficulty),
      sortOrder: metric.sortOrder,
      startIndex: 0,
      endIndex: limit - 1,
    );
    final list = data['leaderboard'];
    if (list is! List) return const [];
    return [
      for (final raw in list)
        if (raw is Map<String, dynamic>) _parse(raw),
    ];
  }

  LeaderboardEntry _parse(Map<String, dynamic> raw) {
    final scoreNum = raw['score'];
    final rankNum = raw['rank'] ?? raw['index'];
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : null;
    // Prefer profile-level name; fall back to the playerName we embedded
    // in the score data; finally fall back to the placeholder.
    final profileName = (raw['name'] ?? raw['playerName'] ?? '').toString();
    final dataName = data?['playerName']?.toString() ?? '';
    final name = profileName.isNotEmpty
        ? profileName
        : (dataName.isNotEmpty ? dataName : 'Player');
    return LeaderboardEntry(
      rank: rankNum is num ? rankNum.toInt() : 0,
      playerId: (raw['playerId'] ?? '').toString(),
      playerName: name,
      score: scoreNum is num ? scoreNum.toInt() : 0,
      data: data,
    );
  }
}
