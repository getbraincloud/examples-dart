import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../services/braincloud_service.dart';
import '../services/leaderboard_service.dart';
import '../services/scoring_service.dart';
import '../services/stats_service.dart';
import '../services/username_service.dart';
import '../widgets/version_footer.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.stats,
    required this.leaderboards,
    required this.usernames,
    required this.scoring,
    required this.bc,
  });

  final StatsService stats;
  final LeaderboardService leaderboards;
  final UsernameService usernames;
  final ScoringService scoring;
  final BrainCloudService bc;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const _prefsNameKey = 'playerDisplayName';

  Difficulty _difficulty = Difficulty.oneSuit;
  String? _playerName;
  bool _initialPromptShown = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsNameKey);
    if (!mounted) return;
    setState(() => _playerName = saved);
    if (saved == null || saved.isEmpty) {
      // First-run: prompt for a name as soon as the menu lands.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialPromptShown) {
          _initialPromptShown = true;
          _editName(firstRun: true);
        }
      });
    }
  }

  Future<void> _editName({bool firstRun = false}) async {
    final controller = TextEditingController(text: _playerName ?? '');
    String? errorText;
    var saving = false;
    var suggestions = const <String>[];

    // Bottom sheet rather than AlertDialog: the sheet pads its content
    // by MediaQuery.viewInsets.bottom, so the form rises above the soft
    // keyboard on phone landscape instead of being obscured by it.
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: !firstRun,
      enableDrag: !firstRun,
      backgroundColor: const Color(0xFF143922),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final raw = controller.text.trim();
            if (raw.isEmpty) {
              setLocal(() => errorText = 'Please enter a name.');
              return;
            }
            setLocal(() {
              saving = true;
              errorText = null;
              suggestions = const [];
            });
            try {
              final claimed = await widget.usernames.claim(raw);
              if (ctx.mounted) Navigator.of(ctx).pop(claimed);
            } on ClaimUsernameException catch (e) {
              setLocal(() {
                saving = false;
                errorText = e.message;
                suggestions = e.suggestions;
              });
            } catch (e) {
              setLocal(() {
                saving = false;
                errorText = '$e';
                suggestions = const [];
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SafeArea(
              top: false,
              // SingleChildScrollView so a short landscape screen with the
              // keyboard up can scroll the form instead of overflowing.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      firstRun ? 'Choose a Display Name' : 'Display Name',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 24,
                      enabled: !saving,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        hintText: 'Shown on leaderboards',
                        errorText: errorText,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    if (firstRun)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Names are unique. Pick one no one else has used.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    if (suggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final s in suggestions)
                                  ActionChip(
                                    label: Text(s),
                                    backgroundColor: Colors.white
                                        .withValues(alpha: 0.12),
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.25),
                                    ),
                                    onPressed: saving
                                        ? null
                                        : () {
                                            controller.text = s;
                                            controller.selection =
                                                TextSelection.collapsed(
                                              offset: s.length,
                                            );
                                            setLocal(() {
                                              errorText = null;
                                              suggestions = const [];
                                            });
                                          },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!firstRun)
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: saving ? null : submit,
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsNameKey, result);
    if (!mounted) return;
    setState(() => _playerName = result);
  }

  bool get _hasName => _playerName != null && _playerName!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Phone landscape gives us ~360–420 px of vertical space; tablets get
    // 600+. Compact mode trims fonts, gaps, button heights, and padding
    // so the menu fits inside short screens without needing to scroll.
    final compact = MediaQuery.of(context).size.height < 500;
    final titleSize = compact ? 28.0 : 42.0;
    final headlineGap = compact ? 4.0 : 12.0;
    final nameSize = compact ? 14.0 : 16.0;
    final sectionGap = compact ? 12.0 : 36.0;
    final headingSize = compact ? 14.0 : 16.0;
    final pickerGap = compact ? 6.0 : 8.0;
    final ctaGap = compact ? 12.0 : 32.0;
    final buttonHeight = compact ? 42.0 : 56.0;
    final buttonFont = compact ? 14.0 : 18.0;
    final buttonGap = compact ? 8.0 : 10.0;
    final outerPadding = compact ? 12.0 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0E5A2B),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(outerPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Spider Solitaire',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: headlineGap),
                      GestureDetector(
                        onTap: () => _editName(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _hasName ? _playerName! : 'Choose a name…',
                              style: TextStyle(
                                color: _hasName ? Colors.white70 : Colors.amber,
                                fontSize: nameSize,
                                fontWeight: _hasName
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit,
                                size: 14, color: Colors.white54),
                          ],
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      Text(
                        'Difficulty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: headingSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: pickerGap),
                      SegmentedButton<Difficulty>(
                        segments: Difficulty.values
                            .map((d) =>
                                ButtonSegment(value: d, label: Text(d.label)))
                            .toList(),
                        selected: {_difficulty},
                        onSelectionChanged: (s) =>
                            setState(() => _difficulty = s.first),
                      ),
                      SizedBox(height: ctaGap),
                      if (compact)
                        _CompactButtonRow(
                          hasName: _hasName,
                          onPlay: _startGame,
                          onLeaderboards: _openLeaderboards,
                          onStats: _openStats,
                          buttonHeight: buttonHeight,
                          buttonFont: buttonFont,
                          gap: buttonGap,
                        )
                      else ...[
                        FilledButton.icon(
                          onPressed: _hasName ? _startGame : null,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                              _hasName ? 'Play' : 'Pick a name to play'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size.fromHeight(buttonHeight),
                            textStyle: TextStyle(fontSize: buttonFont),
                          ),
                        ),
                        SizedBox(height: buttonGap),
                        OutlinedButton.icon(
                          onPressed: _openLeaderboards,
                          icon: const Icon(Icons.emoji_events,
                              color: Colors.white),
                          label: const Text('Leaderboards',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: Size.fromHeight(buttonHeight),
                            textStyle: TextStyle(fontSize: buttonFont),
                          ),
                        ),
                        SizedBox(height: buttonGap),
                        OutlinedButton.icon(
                          onPressed: _openStats,
                          icon: const Icon(Icons.bar_chart,
                              color: Colors.white),
                          label: const Text('Stats',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: Size.fromHeight(buttonHeight),
                            textStyle: TextStyle(fontSize: buttonFont),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VersionFooter(bc: widget.bc),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        difficulty: _difficulty,
        stats: widget.stats,
        leaderboards: widget.leaderboards,
        scoring: widget.scoring,
        bc: widget.bc,
      ),
    ));
  }

  void _openStats() {
    showDialog<void>(
      context: context,
      builder: (_) => StatsScreen(stats: widget.stats, bc: widget.bc),
    );
  }

  void _openLeaderboards() {
    showDialog<void>(
      context: context,
      builder: (_) => LeaderboardScreen(
        leaderboards: widget.leaderboards,
        bc: widget.bc,
      ),
    );
  }
}

/// Horizontal three-button row used in compact (phone-landscape) mode so
/// Play / Leaderboards / Stats all fit on one line without scrolling.
class _CompactButtonRow extends StatelessWidget {
  const _CompactButtonRow({
    required this.hasName,
    required this.onPlay,
    required this.onLeaderboards,
    required this.onStats,
    required this.buttonHeight,
    required this.buttonFont,
    required this.gap,
  });

  final bool hasName;
  final VoidCallback onPlay;
  final VoidCallback onLeaderboards;
  final VoidCallback onStats;
  final double buttonHeight;
  final double buttonFont;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final outlined = OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.white54),
      minimumSize: Size.fromHeight(buttonHeight),
      textStyle: TextStyle(fontSize: buttonFont),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: hasName ? onPlay : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Play'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(buttonHeight),
              textStyle: TextStyle(fontSize: buttonFont),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onLeaderboards,
            icon: const Icon(Icons.emoji_events,
                color: Colors.white, size: 18),
            label: const Text('Leaders',
                style: TextStyle(color: Colors.white)),
            style: outlined,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onStats,
            icon: const Icon(Icons.bar_chart, color: Colors.white, size: 18),
            label: const Text('Stats',
                style: TextStyle(color: Colors.white)),
            style: outlined,
          ),
        ),
      ],
    );
  }
}
