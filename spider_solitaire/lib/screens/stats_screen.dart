import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../format.dart';
import '../services/braincloud_service.dart';
import '../services/stats_service.dart';

/// Stats popup. Show with `showDialog(...)`.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.stats, required this.bc});

  final StatsService stats;
  final BrainCloudService bc;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  PlayerStats? _data;
  Object? _error;
  bool _loading = true;
  bool _testing = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.stats.fetch();
      if (!mounted) return;
      setState(() {
        _data = s;
        _loading = false;
        _lastSync = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _runSyncTest() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.bc.incrementUserStats({StatKeys.gamesPlayed: 1});
      await _refresh();
      messenger.showSnackBar(const SnackBar(
        content: Text('Sync test OK — gamesPlayed incremented by 1.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Sync test failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _fmtTime(int seconds) {
    if (seconds <= 0) return '—';
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _fmtInt(int v) => v <= 0 ? '—' : withCommas(v);

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
              Expanded(child: _body()),
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
            'Stats',
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
            onPressed: _loading ? null : _refresh,
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

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) return _errorView();
    return _statsView(_data ?? PlayerStats.empty);
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.white70),
          const SizedBox(height: 8),
          const Text(
            'Could not load stats',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  Widget _statsView(PlayerStats s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _row('Games played', _fmtInt(s.gamesPlayed)),
        _row('Games won', _fmtInt(s.gamesWon)),
        _row('Current win streak', _fmtInt(s.currentWinStreak)),
        _row('Longest win streak', _fmtInt(s.longestWinStreak)),
        _row('High score', _fmtInt(s.highScore)),
        _row('Fastest win', _fmtTime(s.fastestTimeSeconds)),
        _row('Fewest moves', _fmtInt(s.fewestMoves)),
        const SizedBox(height: 12),
        _diagnostics(),
      ],
    );
  }

  Widget _diagnostics() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diagnostics',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Profile ID: ',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: SelectableText(
                  widget.bc.profileId.isEmpty
                      ? '(not authenticated)'
                      : widget.bc.profileId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.bc.profileId.isEmpty
                    ? null
                    : () => Clipboard.setData(
                        ClipboardData(text: widget.bc.profileId)),
              ),
            ],
          ),
          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Last sync: ${_lastSync!.toIso8601String().substring(0, 19)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            icon: _testing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.bolt, size: 18),
            label: const Text('Run Sync Test'),
            onPressed: _testing ? null : _runSyncTest,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
