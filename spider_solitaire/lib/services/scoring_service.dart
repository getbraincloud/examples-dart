import '../models/scoring_config.dart';
import 'braincloud_service.dart';

/// Loads [ScoringConfig] from brainCloud's globalProperties and caches
/// it for the rest of the session.
///
/// Failures are swallowed: if the server is unreachable, the property
/// names aren't configured in the portal, or any value can't be parsed,
/// the cached config falls back to [ScoringConfig]'s baked-in defaults
/// so the game remains playable.
class ScoringService {
  ScoringService(this._bc);
  final BrainCloudService _bc;

  ScoringConfig _config = const ScoringConfig();

  /// Latest loaded config, or the defaults if [load] hasn't run yet.
  ScoringConfig get config => _config;

  /// Pulls the scoring globalProperties from brainCloud and updates
  /// [config]. Never throws — on error the previous/default config
  /// stays in place.
  Future<ScoringConfig> load() async {
    try {
      final props = await _bc.readGlobalProperties(ScoringConfig.allKeys);
      _config = const ScoringConfig().withOverrides(props);
    } catch (e) {
      // ignore: avoid_print
      print('ScoringService.load failed, using defaults: $e');
      _config = const ScoringConfig();
    }
    return _config;
  }
}
