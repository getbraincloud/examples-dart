import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../game/spider_game.dart';
import '../models/difficulty.dart';
import '../services/braincloud_service.dart';
import '../services/leaderboard_service.dart';
import '../services/scoring_service.dart';
import '../services/stats_service.dart';
import '../widgets/version_footer.dart';

/// On short screens (phone landscape) we collapse the top status bar
/// into a vertical sidebar on the right, plus a tiny floating back
/// button overlaid at the top-left of the playfield. This threshold
/// gates the layout.
const double _kCompactHeightThreshold = 500;
const double _kSidebarWidth = 120;
const double _kTopBarHeight = 60;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    required this.leaderboards,
    required this.scoring,
    required this.bc,
  });

  final Difficulty difficulty;
  final StatsService stats;
  final LeaderboardService leaderboards;
  final ScoringService scoring;
  final BrainCloudService bc;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SpiderGame _game;
  Timer? _ticker;
  bool _resultSubmitted = false;
  bool _gameCreated = false;
  String? _playerName;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    _loadPlayerName();
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _playerName = prefs.getString('playerDisplayName'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create the SpiderGame once we have access to MediaQuery so we can
    // shape the virtual viewport to match the actual playfield aspect.
    // didChangeDependencies fires multiple times during the screen's
    // lifetime; the flag keeps us from rebuilding the game on resize.
    if (!_gameCreated) {
      _gameCreated = true;
      final size = MediaQuery.of(context).size;
      // In compact (phone-landscape) mode the right sidebar takes
      // _kSidebarWidth pixels off the available width; in normal mode the
      // top bar takes _kTopBarHeight off the height. Either way we want
      // the virtual canvas aspect to match the real Flame area so the
      // FixedResolutionViewport doesn't letterbox.
      final compact = size.height < _kCompactHeightThreshold;
      // Compact mode has no horizontal top bar — the back button sits as
      // a tiny floating overlay so the cards can use the full top of the
      // playfield. Only the right sidebar takes any chrome space.
      final canvasWidth = compact ? size.width - _kSidebarWidth : size.width;
      final canvasHeight = compact ? size.height : size.height - _kTopBarHeight;
      final aspect = canvasHeight > 0 ? canvasWidth / canvasHeight : null;
      _game = SpiderGame(
        difficulty: widget.difficulty,
        // Snapshot the live ScoringService config at construction so a
        // mid-session refresh doesn't change the rules of the game
        // already in progress.
        scoring: widget.scoring.config,
        onWon: _handleWin,
        onChanged: () => setState(() {}),
        onGameOver: _handleGameOver,
        screenAspect: aspect,
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final s = _game.state.elapsedSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _handleWin(int score, int seconds, int moves) async {
    if (_resultSubmitted) return;
    _resultSubmitted = true;
    _ticker?.cancel();
    String? statError;
    try {
      await widget.stats.recordGameResult(GameResult(
        won: true,
        score: score,
        elapsedSeconds: seconds,
        moves: moves,
      ));
    } catch (e) {
      statError = '$e';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('playerDisplayName');
      await widget.leaderboards.postWin(
        difficulty: widget.difficulty,
        score: score,
        elapsedSeconds: seconds,
        moves: moves,
        playerName: savedName,
      );
    } catch (e) {
      // Don't overwrite the stats error if both fail; just append.
      statError = statError == null ? 'Leaderboard: $e' : '$statError\nLeaderboard: $e';
    }
    if (!mounted) return;
    if (statError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync failed: $statError'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ));
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('You Win!'),
        content: Text(
          'Score: ${withCommas(score)}\nTime: $_timerLabel\nMoves: ${withCommas(moves)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  /// Auto-fires from SpiderGame when the board has no advancing moves
  /// and the stock is empty. Records the loss and offers the player a
  /// way out.
  Future<void> _handleGameOver() async {
    if (_resultSubmitted) return;
    final finalScore = _game.state.finalScore;
    await _recordLoss();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(
          'No moves can advance the board and the stock is empty.\n\n'
          'Final score: ${withCommas(finalScore)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  /// True while a game is actively in progress and could be counted as a
  /// loss if the player walks away or restarts.
  bool get _hasActiveGame =>
      !_resultSubmitted && _game.state.moves > 0;

  Future<bool> _confirmDiscard(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'The current game will count as a loss and reset your win streak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Records the current game as a loss (increments gamesPlayed, resets
  /// the win streak, bumps the high-score stat if the partial score
  /// beats the current best) and posts the partial score to the
  /// high-score leaderboard. Time / fewest-moves leaderboards are
  /// deliberately skipped — a half-finished round shouldn't compete
  /// against completed games on those.
  ///
  /// Surfaces errors via SnackBar but does not block the loss flow.
  Future<void> _recordLoss() async {
    _resultSubmitted = true;
    _ticker?.cancel();
    final score = _game.state.finalScore;
    final seconds = _game.state.elapsedSeconds;
    final moves = _game.state.moves;
    String? error;
    try {
      await widget.stats.recordGameResult(GameResult(
        won: false,
        score: score,
        elapsedSeconds: seconds,
        moves: moves,
      ));
    } catch (e) {
      error = 'Stats: $e';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('playerDisplayName');
      await widget.leaderboards.postHighScore(
        difficulty: widget.difficulty,
        score: score,
        elapsedSeconds: seconds,
        moves: moves,
        playerName: savedName,
      );
    } catch (e) {
      error = error == null ? 'Leaderboard: $e' : '$error\nLeaderboard: $e';
    }
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sync failed: $error'),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _newGame() async {
    // Ask for confirmation whenever the current game hasn't already been
    // resolved (won, lost, or abandoned). This includes the just-dealt
    // case where the user hasn't made any moves yet — it's still easy to
    // tap the new-game icon by accident. We only record a loss if at
    // least one move was actually played.
    if (!_resultSubmitted) {
      if (!await _confirmDiscard('Start a new game?')) return;
      if (_game.state.moves > 0) {
        await _recordLoss();
      }
    }
    if (!mounted) return;
    _ticker?.cancel();
    setState(() {
      _resultSubmitted = false;
      _game.restart();
    });
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  Future<void> _confirmAbandon() async {
    if (!_hasActiveGame) {
      Navigator.of(context).pop();
      return;
    }
    if (!await _confirmDiscard('Abandon game?')) return;
    await _recordLoss();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _game.state;
    final compact =
        MediaQuery.of(context).size.height < _kCompactHeightThreshold;

    void handleHint() {
      final result = _game.showHint();
      if (!mounted) return;
      switch (result) {
        case HintResult.shown:
        case HintResult.dealFromStock:
          return;
        case HintResult.gameOver:
          _handleGameOver();
          return;
        case HintResult.busy:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wait for the deal to finish.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
      }
    }

    void handleUndo() {
      _game.undo();
      setState(() {});
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAbandon();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E5A2B),
        body: Stack(
          children: [
            SafeArea(
              child: compact
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: GameWidget(game: _game)),
                        _RightSideBar(
                          playerName: _playerName,
                          score: s.score,
                          moves: s.moves,
                          time: _timerLabel,
                          stockRemaining: s.stock.length ~/ 10,
                          canUndo: _game.canUndo,
                          onRestart: () => _newGame(),
                          onUndo: handleUndo,
                          onHint: handleHint,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _TopBar(
                          difficulty: widget.difficulty.label,
                          playerName: _playerName,
                          score: s.score,
                          moves: s.moves,
                          time: _timerLabel,
                          stockRemaining: s.stock.length ~/ 10,
                          canUndo: _game.canUndo,
                          onBack: () => _confirmAbandon(),
                          onRestart: () => _newGame(),
                          onUndo: handleUndo,
                          onHint: handleHint,
                        ),
                        Expanded(child: GameWidget(game: _game)),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
            // Screen-bottom version overlay only in normal mode. In
            // compact mode the version label lives inside the sidebar
            // so the Flame canvas can reach the bottom of the screen.
            if (!compact)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VersionFooter(bc: widget.bc),
              ),
            // Floating back button overlay in compact mode. Sits above
            // the cards in the top-left corner of the playfield; cards
            // beneath it are still mostly face-down so the overlap is
            // visually quiet.
            if (compact)
              Positioned(
                top: 4,
                left: 4,
                child: SafeArea(
                  child: Material(
                    color: const Color(0xFF093E1D).withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _confirmAbandon(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.difficulty,
    required this.playerName,
    required this.score,
    required this.moves,
    required this.time,
    required this.stockRemaining,
    required this.canUndo,
    required this.onBack,
    required this.onRestart,
    required this.onUndo,
    required this.onHint,
  });

  final String difficulty;
  final String? playerName;
  final int score;
  final int moves;
  final String time;
  final int stockRemaining;
  final bool canUndo;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onUndo;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF093E1D),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          if (playerName != null && playerName!.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                playerName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Centred difficulty label — Expanded + Center keeps it in the
          // visual middle of the top bar regardless of the widths of the
          // left and right groups.
          Expanded(
            child: Center(
              child: Text(
                difficulty,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          _stat('Score', withCommas(score)),
          _stat('Moves', withCommas(moves)),
          _stat('Time', time),
          _stat('Deals', '$stockRemaining'),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
            tooltip: 'Hint',
            onPressed: onHint,
          ),
          IconButton(
            icon: Icon(Icons.undo,
                color: canUndo ? Colors.white : Colors.white24),
            tooltip: 'Undo',
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'New game',
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              )),
        ],
      ),
    );
  }
}

/// Vertical right-side status panel used on short (phone-landscape)
/// screens in place of the horizontal top bar. Contains the same
/// information and controls, stacked from top to bottom: back arrow,
/// player name, bold difficulty label, four stats, action buttons.
class _RightSideBar extends StatelessWidget {
  const _RightSideBar({
    required this.playerName,
    required this.score,
    required this.moves,
    required this.time,
    required this.stockRemaining,
    required this.canUndo,
    required this.onRestart,
    required this.onUndo,
    required this.onHint,
  });

  final String? playerName;
  final int score;
  final int moves;
  final String time;
  final int stockRemaining;
  final bool canUndo;
  final VoidCallback onRestart;
  final VoidCallback onUndo;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      color: const Color(0xFF093E1D),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      // New button at the very top, separated from Hint/Undo at the
      // bottom by the player name + stats. That spacing makes a tap on
      // New (the destructive one) far less likely to be mis-hit.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarActionButton(
            icon: Icons.add_circle_outline,
            iconColor: Colors.white,
            label: 'New',
            onTap: onRestart,
          ),
          const SizedBox(height: 6),
          if (playerName != null && playerName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                playerName!,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _SidebarStat(label: 'Score', value: withCommas(score)),
          _SidebarStat(label: 'Moves', value: withCommas(moves)),
          _SidebarStat(label: 'Time', value: time),
          _SidebarStat(label: 'Deals', value: '$stockRemaining'),
          const Spacer(),
          _SidebarActionButton(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber,
            label: 'Hint',
            onTap: onHint,
          ),
          const SizedBox(height: 3),
          _SidebarActionButton(
            icon: Icons.undo,
            iconColor: canUndo ? Colors.white : Colors.white38,
            label: 'Undo',
            onTap: canUndo ? onUndo : null,
          ),
        ],
      ),
    );
  }
}

/// Full-width sidebar button with a leading icon and a label below.
/// Designed to be tall enough to be an easy phone target (~40 px) and
/// fill the sidebar width so the hitbox spans the whole row.
class _SidebarActionButton extends StatelessWidget {
  const _SidebarActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.white38 : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  const _SidebarStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
