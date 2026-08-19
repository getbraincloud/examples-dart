# spider_solitaire

Spider Solitaire built with Flutter + Flame, backed by brainCloud for anonymous auth and player stats.

## Prerequisites

See the [repository README](../README.md) for installing Flutter and creating a brainCloud app. This sample additionally needs:
* The `claim_username` cloud code script uploaded to your app — see the header comment in [`cloud_code/claim_username.ccjs`](cloud_code/claim_username.ccjs) for the one-time portal setup (Design > Cloud Code > Scripts), including making player display names searchable.
* The `post_leaderboard_scores` cloud code script uploaded to your app — see the header comment in [`cloud_code/post_leaderboard_scores.ccjs`](cloud_code/post_leaderboard_scores.ccjs) for the one-time portal setup (Design > Cloud Code > Scripts). This batches the high-score/fastest-time/fewest-moves leaderboard posts into a single `runScript` call instead of one direct API call per leaderboard.
* The user statistics below, defined in the portal before the app can read or increment them.

### Adding the user statistics

This sample tracks player progress with brainCloud Player Statistics. In the brainCloud portal, go to **Design > Statistics Rules > User Statistics** and add each of these as an **Integer** stat with a default value of `0` (names must match exactly — see [`lib/config.dart`](lib/config.dart)):

| Stat name | Tracks |
|---|---|
| `gamesPlayed` | Total games started |
| `gamesWon` | Total games won |
| `currentWinStreak` | Current consecutive-win streak |
| `longestWinStreak` | Longest consecutive-win streak achieved |
| `highScore` | Personal best score |
| `fastestTimeSeconds` | Fastest completion time, in seconds, for a won game |
| `fewestMoves` | Fewest moves used to win a game |

The app reads these via `readAllUserStats` and updates them via `incrementUserStats` after each game (see [`lib/services/stats_service.dart`](lib/services/stats_service.dart)); calling either against a stat that doesn't exist yet in the portal will fail.

## Getting Started

1. Install dependencies:
```shell
flutter pub get
```

2. Create a `bc_config.json` file in this folder, pointing at your own brainCloud app:
```json
{
    "serverUrl": "https://api.braincloudservers.com/dispatcherv2",
    "secretKey": "<app secret from brainCloud portal>",
    "appId": "<app id from brainCloud portal>",
    "version": "1.0.0"
}
```

3. Run the app:
```shell
flutter run --dart-define-from-file=bc_config.json
```
