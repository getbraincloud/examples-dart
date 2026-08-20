import 'dart:async';

import 'package:braincloud/braincloud.dart';
import 'package:braincloud/data_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SharedPrefsPersistence implements DataPersistenceBase {
  @override
  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}

/// Thin wrapper around the brainCloud SDK for Spider Solitaire.
class BrainCloudService {
  BrainCloudService({
    required this.serverUrl,
    required this.appId,
    required this.appVersion,
    required this.serverSecret,
    String wrapperName = 'spider_solitaire_wrapper',
    BrainCloudWrapper? wrapper,
  }) : _bc =
           wrapper ??
           BrainCloudWrapper(
             wrapperName: wrapperName,
             persistence: _SharedPrefsPersistence(),
           );

  final String serverUrl;
  final String appId;
  final String appVersion;
  final String serverSecret;
  final BrainCloudWrapper _bc;

  BrainCloudWrapper get wrapper => _bc;
  bool get isAuthenticated => _bc.brainCloudClient.isAuthenticated();
  String get profileId => _bc.brainCloudClient.profileId ?? '';

  /// brainCloud Dart SDK version (e.g. "5.5.0.3").
  String get sdkVersion => _bc.brainCloudClient.brainCloudClientVersion;

  Future<void> init() async {
    await _bc.init(
      secretKey: serverSecret,
      appId: appId,
      version: appVersion,
      url: serverUrl,
      updateTick: 50,
    );
    _bc.enableAutoReconnect(true);
  }

  Future<void> authenticateAnonymous() async {
    var response = await _bc.authenticateAnonymous();
    if (!response.isSuccess() && response.reasonCode == 40206) {
      // Stale profile stored locally no longer exists on the server.
      // Reset and create a fresh anonymous profile.
      _bc.resetStoredProfileId();
      _bc.resetStoredAnonymousId();
      response = await _bc.authenticateAnonymous();
    }
    if (!response.isSuccess()) {
      throw StateError(
        'brainCloud anonymous auth failed '
        '${response.statusCode} (${response.reasonCode}): ${response.error}',
      );
    }
  }

  /// Increment user statistics. brainCloud will create the stat row if a
  /// matching key is defined in the portal and the user has none yet.
  Future<Map<String, dynamic>> incrementUserStats(
    Map<String, dynamic> increments,
  ) async {
    final response = await _bc.playerStatisticsService.incrementUserStats(
      statistics: increments,
    );
    _throwIfFailed(response, 'incrementUserStats');
    return _unwrap(response.data);
  }

  /// Read all of the current user's statistics.
  Future<Map<String, dynamic>> readAllUserStats() async {
    final response = await _bc.playerStatisticsService.readAllUserStats();
    _throwIfFailed(response, 'readAllUserStats');
    return _unwrap(response.data);
  }

  /// Sets this user's displayed name directly on the profile. Does NOT
  /// check for uniqueness — use the `claim_username` Cloud Code script
  /// via [runScript] if you want unique display names.
  Future<void> updateUserName(String name) async {
    final response = await _bc.playerStateService.updateUserName(
      userName: name,
    );
    _throwIfFailed(response, 'updateUserName');
  }

  /// Reads the named entries from brainCloud's global properties and
  /// returns them as a flat `{name: stringValue}` map.
  ///
  /// brainCloud's `readSelectedProperties` returns each property as a
  /// `{value, category, description, ...}` object; we keep only the
  /// `value` field since that's all the client needs. Missing keys are
  /// simply absent from the result (brainCloud doesn't error on
  /// unknown property names). Values are returned as strings so callers
  /// can parse them however they like — globalProperties are typed as
  /// strings server-side regardless of what number they encode.
  Future<Map<String, String>> readGlobalProperties(
    List<String> propertyNames,
  ) async {
    if (propertyNames.isEmpty) return const <String, String>{};
    final response = await _bc.globalAppService.readSelectedProperties(
      propertyNames: propertyNames,
    );
    _throwIfFailed(response, 'readSelectedProperties');
    final data = _unwrap(response.data);
    final result = <String, String>{};
    data.forEach((key, value) {
      if (value is Map && value['value'] != null) {
        result[key] = value['value'].toString();
      } else if (value is String || value is num) {
        // Some runtimes return the bare value instead of a wrapper.
        result[key] = value.toString();
      }
    });
    return result;
  }

  /// Runs a Cloud Code script and returns its parsed response.
  ///
  /// The response is unwrapped from brainCloud's `{response: {...}}`
  /// envelope. Scripts may return error envelopes of the form
  /// `{status, reason_code, status_message, ...}` inside that response;
  /// callers are responsible for checking `data['status']` themselves
  /// so they can also read script-specific fields (e.g. suggestions
  /// from `claim_username`). Only the outer HTTP-style response is
  /// translated into a thrown exception here.
  Future<Map<String, dynamic>> runScript(
    String scriptName, {
    Map<String, dynamic> scriptData = const {},
  }) async {
    final response = await _bc.scriptService.runScript(
      scriptName: scriptName,
      scriptData: scriptData,
    );
    _throwIfFailed(response, 'runScript($scriptName)');
    return _unwrap(response.data);
  }

  /// Posts a batch of scores via the `post_leaderboard_scores` Cloud
  /// Code script, so N leaderboard posts cost one `runScript` call
  /// instead of N direct `postScoreToDynamicLeaderboardUTC` calls.
  ///
  /// Each entry must contain `leaderboardId`, `score`, `leaderboardType`,
  /// `rotationType`, and `retainedCount` (all as the wire strings/values
  /// brainCloud expects — see `SocialLeaderboardType`/`RotationType`
  /// `.value`), plus an optional `data` payload.
  ///
  /// This is critical: brainCloud's default leaderboard config keeps the
  /// *highest* score per player, which silently drops every
  /// faster-time / fewer-move post on a LOW_VALUE leaderboard. Passing
  /// the type at post time ensures any freshly-created leaderboard is
  /// configured correctly. Existing leaderboards keep whatever type they
  /// were created with, so if they were misconfigured you must delete
  /// them in the portal first (Design → Leaderboards → Leaderboard
  /// Configs).
  Future<void> postScores(List<Map<String, dynamic>> scores) async {
    final response = await runScript(
      'post_leaderboard_scores',
      scriptData: {'scores': scores},
    );
    if (response['success'] != true) {
      throw StateError('post_leaderboard_scores failed: $response');
    }
  }

  /// Returns one page of entries from a global leaderboard.
  ///
  /// brainCloud expects `sortOrder` to match the way the leaderboard was
  /// configured on the server. The returned map contains a `leaderboard`
  /// list with `[{playerId, playerName, score, data, rank, ...}, ...]`.
  ///
  /// A leaderboard only starts existing once someone posts the first score
  /// to it (see `postScores`), so reading one nobody has played yet returns
  /// `noLeaderboardFound` rather than an empty page — treat that the same
  /// as "no entries" instead of surfacing it as an error.
  Future<Map<String, dynamic>> getLeaderboardPage({
    required String leaderboardId,
    required SortOrder sortOrder,
    int startIndex = 0,
    int endIndex = 99,
  }) async {
    final response = await _bc.socialLeaderboardService
        .getGlobalLeaderboardPage(
          leaderboardId: leaderboardId,
          sortOrder: sortOrder,
          startIndex: startIndex,
          endIndex: endIndex,
        );
    if (!response.isSuccess() &&
        response.reasonCode == ReasonCodes.noLeaderboardFound) {
      return const {'leaderboard': []};
    }
    _throwIfFailed(response, 'getGlobalLeaderboardPage($leaderboardId)');
    return _unwrap(response.data);
  }

  void _throwIfFailed(ServerResponse response, String label) {
    if (!response.isSuccess()) {
      throw StateError(
        'brainCloud $label failed '
        '${response.statusCode} (${response.reasonCode}): ${response.error}',
      );
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? data) {
    var map = data ?? <String, dynamic>{};
    while (map['response'] is Map<String, dynamic>) {
      map = map['response'] as Map<String, dynamic>;
    }
    return map;
  }

  void dispose() => _bc.onDestroy();
}
