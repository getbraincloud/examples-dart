import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'screens/menu_screen.dart';
import 'services/braincloud_service.dart';
import 'services/leaderboard_service.dart';
import 'services/scoring_service.dart';
import 'services/stats_service.dart';
import 'services/username_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to landscape: the 10-column tableau + the top-bar layout don't
  // fit in phone portrait (the bar's Row overflows horizontally and gets
  // silently clipped in release builds, hiding the status). Tablets in
  // portrait would technically have room but for consistency we lock
  // landscape across the app.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SpiderSolitaireApp());
}

class SpiderSolitaireApp extends StatelessWidget {
  const SpiderSolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spider Solitaire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E5A2B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _Bootstrapper(),
    );
  }
}

class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper();

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _AppHandle {
  _AppHandle(
    this.bc,
    this.stats,
    this.leaderboards,
    this.usernames,
    this.scoring,
  );
  final BrainCloudService bc;
  final StatsService stats;
  final LeaderboardService leaderboards;
  final UsernameService usernames;
  final ScoringService scoring;
}

class _BootstrapperState extends State<_Bootstrapper> {
  late Future<_AppHandle> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<_AppHandle> _init() async {
    final bc = BrainCloudService(
      serverUrl: BrainCloudConfig.serverUrl,
      appId: BrainCloudConfig.appId,
      serverSecret: BrainCloudConfig.serverSecret,
      appVersion: BrainCloudConfig.appVersion,
      wrapperName: BrainCloudConfig.wrapperName,
    );
    await bc.init();
    if (!bc.isAuthenticated) {
      await bc.authenticateAnonymous();
    }
    // Load the scoring globalProperties before the menu lands so the
    // first game uses the live values. ScoringService swallows errors
    // and falls back to defaults, so a missing config in the portal
    // doesn't block startup.
    final scoring = ScoringService(bc);
    await scoring.load();
    return _AppHandle(
      bc,
      StatsService(bc),
      LeaderboardService(bc),
      UsernameService(bc),
      scoring,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppHandle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0E5A2B),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF0E5A2B),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not connect to brainCloud',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(() {
                          _future = _init();
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final handle = snap.data!;
        return MenuScreen(
          stats: handle.stats,
          leaderboards: handle.leaderboards,
          usernames: handle.usernames,
          scoring: handle.scoring,
          bc: handle.bc,
        );
      },
    );
  }
}
