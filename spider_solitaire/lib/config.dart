/// brainCloud configuration.
///
/// Replace these placeholders with the App ID and Server Secret from the
/// brainCloud Design Portal (Application IDs page).
class BrainCloudConfig {
  static const String serverUrl = String.fromEnvironment('serverUrl');
  static const String appId = String.fromEnvironment('appId');
  static const String serverSecret = String.fromEnvironment('secretKey');
  static const String appVersion = String.fromEnvironment('version');
  static const String wrapperName = 'spider_solitaire_wrapper';
}

/// Keys used for brainCloud Player Statistics.
///
/// These must be defined under "Design > Statistics Rules > User Statistics"
/// in the brainCloud portal before they can be incremented or read.
class StatKeys {
  static const String gamesPlayed = 'gamesPlayed';
  static const String gamesWon = 'gamesWon';
  static const String currentWinStreak = 'currentWinStreak';
  static const String longestWinStreak = 'longestWinStreak';
  static const String highScore = 'highScore';
  static const String fastestTimeSeconds = 'fastestTimeSeconds';
  static const String fewestMoves = 'fewestMoves';
}

/// brainCloud Leaderboard IDs.
///
/// Three metrics × three difficulty levels = nine leaderboards. Each one
/// must be created in the brainCloud portal under "Design > Leaderboards
/// > Leaderboard Configs". See README for required settings.
class LeaderboardIds {
  static String highScore(int suitCount) =>
      'spider_high_score_${suitCount}suit';
  static String fastestTime(int suitCount) =>
      'spider_fastest_time_${suitCount}suit';
  static String fewestMoves(int suitCount) =>
      'spider_fewest_moves_${suitCount}suit';
}
