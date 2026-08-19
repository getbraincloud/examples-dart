import 'package:braincloud/braincloud.dart';
import 'package:flutter/material.dart';

const String leaderboardId = "AceyDeucyPlayers";
const int leaderboardAround = 5;

class LeaderboardPage extends StatefulWidget {
  final BrainCloudWrapper bcWrapper;
  final String? userId;

  const LeaderboardPage({super.key, required this.bcWrapper, this.userId});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<dynamic> leaderboard = [];
  int leaderboardRank = 0;
  int pageOffset = 0;
  bool disablePrev = false;
  bool disableNext = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAroundPlayer();
  }

  Future<void> _loadAroundPlayer() async {
    setState(() => loading = true);

    ServerResponse response =
        await widget.bcWrapper.socialLeaderboardService.getGlobalLeaderboardView(
      leaderboardId: leaderboardId,
      sortOrder: SortOrder.HIGH_TO_LOW,
      beforeCount: leaderboardAround - 1,
      afterCount: leaderboardAround,
    );

    if (response.statusCode == StatusCodes.ok) {
      List<dynamic> entries = response.data?["leaderboard"] ?? [];
      for (var entry in entries) {
        if (entry["playerId"] == widget.userId) {
          leaderboardRank = entry["rank"];
        }
      }
      setState(() {
        leaderboard = entries;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _pageLeaderboard(int direction) async {
    pageOffset += direction;

    int start = (leaderboardRank - 4 > 0 ? leaderboardRank - 4 : 0) +
        (pageOffset * (leaderboardAround * 2));

    if (start <= 0) {
      start = 0;
      disablePrev = true;
    } else {
      disablePrev = false;
    }

    int end = start + (2 * leaderboardAround) - 1;

    ServerResponse response =
        await widget.bcWrapper.socialLeaderboardService.getGlobalLeaderboardPage(
      leaderboardId: leaderboardId,
      sortOrder: SortOrder.HIGH_TO_LOW,
      startIndex: start,
      endIndex: end,
    );

    if (response.statusCode == StatusCodes.ok) {
      setState(() {
        leaderboard = response.data?["leaderboard"] ?? [];
        disableNext = !(response.data?["moreAfter"] ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text("Leaderboards"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final player = leaderboard[index];
                      final data = player["data"] ?? {};
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          child: Text("${player["rank"]}"),
                        ),
                        title: Text(player["name"] ?? player["playerId"] ?? ""),
                        subtitle: Text(
                            "Dollars Won: \$${data["DollarsWon"] ?? 0}  Refills: ${data["Refills"] ?? 0}"),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: disablePrev ? null : () => _pageLeaderboard(-1),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white),
                        child: const Text("Previous"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: disableNext ? null : () => _pageLeaderboard(1),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white),
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
