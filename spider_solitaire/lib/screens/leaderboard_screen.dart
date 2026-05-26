import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../models/difficulty.dart';
import '../services/braincloud_service.dart';
import '../services/leaderboard_service.dart';

/// Leaderboard popup. Show with `showDialog(...)`.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.leaderboards,
    required this.bc,
  });

  final LeaderboardService leaderboards;
  final BrainCloudService bc;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _prefsNameKey = 'playerDisplayName';

  Difficulty _difficulty = Difficulty.oneSuit;
  LeaderboardMetric _metric = LeaderboardMetric.highScore;
  late Future<List<LeaderboardEntry>> _future;
  String? _myLocalName;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadMyName();
  }

  Future<void> _loadMyName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _myLocalName = prefs.getString(_prefsNameKey));
  }

  Future<List<LeaderboardEntry>> _load() => widget.leaderboards.fetchTop(
        difficulty: _difficulty,
        metric: _metric,
      );

  void _refresh() => setState(() {
        _future = _load();
      });

  String _formatScore(LeaderboardEntry e) {
    switch (_metric) {
      case LeaderboardMetric.fastestTime:
        final s = e.score;
        final mm = (s ~/ 60).toString().padLeft(2, '0');
        final ss = (s % 60).toString().padLeft(2, '0');
        return '$mm:$ss';
      case LeaderboardMetric.fewestMoves:
      case LeaderboardMetric.highScore:
        return withCommas(e.score);
    }
  }

  String _displayName(LeaderboardEntry e, String myProfileId) {
    if (e.playerId == myProfileId &&
        _myLocalName != null &&
        _myLocalName!.isNotEmpty) {
      return _myLocalName!;
    }
    return e.playerName.isEmpty ? 'Player' : e.playerName;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0E5A2B),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: SizedBox(
          width: 460,
          height: 620,
          child: Column(
            children: [
              _titleBar(),
              _pickers(),
              Expanded(child: _list()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 6, 4),
      child: Row(
        children: [
          const Text(
            'Leaderboards',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _pickers() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          SegmentedButton<Difficulty>(
            segments: Difficulty.values
                .map((d) => ButtonSegment(value: d, label: Text(d.label)))
                .toList(),
            selected: {_difficulty},
            onSelectionChanged: (s) {
              setState(() {
                _difficulty = s.first;
                _future = _load();
              });
            },
          ),
          const SizedBox(height: 6),
          SegmentedButton<LeaderboardMetric>(
            segments: LeaderboardMetric.values
                .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                .toList(),
            selected: {_metric},
            onSelectionChanged: (s) {
              setState(() {
                _metric = s.first;
                _future = _load();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Could not load leaderboard:\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }
        final entries = snap.data ?? const [];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No scores yet — be the first!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          );
        }
        final me = widget.bc.profileId;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            final e = entries[i];
            final isMe = e.playerId == me;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.amber.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: isMe
                    ? Border.all(
                        color: Colors.amber.withValues(alpha: 0.6),
                        width: 1.2)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${e.rank > 0 ? e.rank : i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _displayName(e, me),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatScore(e),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
