# Acey Deucey

Acey Deucey is a casino-style game in which players bet on whether a drawn card will be between two others. In general, the greater the gap between the two cards, the higher a bet should be.

There are three outcomes when the third card is flipped:

- The card is between the other two. Win 1.5x bet.
- The card is outside the other two. Win 0.5x bet.
- The card matches one of the other two. Lose bet.

Unless the third card is between the other two (option 1), a portion of the money lost contributes to the jackpot.

This sample demonstrates usage of the [brainCloud Dart client SDK](https://github.com/getbraincloud/braincloud-dart).

## Prerequisites

See the [repository README](../README.md) for prerequisites and how to create a brainCloud app. This sample additionally needs the user statistics, global properties, and global statistics below, defined in the portal before the app can run correctly.

### Adding the user statistics

This sample tracks player results with brainCloud Player Statistics. In the brainCloud portal, go to **Design > Statistics Rules > User Statistics** and add each of these as an **Integer** stat with a default value of `0` (names must match exactly — see `lib/main.dart`):

| Stat name | Tracks |
|---|---|
| `Wins` | Total hands won |
| `Losses` | Total hands lost |
| `DollarsWon` | Total winnings across all hands |
| `Posts` | Total hands lost to a matching card (contributes to the jackpot) |
| `Refills` | Times the player's currency balance was topped up |

The app increments these via `playerStatisticsService.incrementUserStats` after each hand; incrementing a stat that doesn't exist yet in the portal will fail.

### Adding the global properties

This sample also reads game-balance settings via `globalAppService.readProperties()`. Without these defined in the portal, the values parse to nothing and the app silently falls back to `0` — quick-bet buttons and the starting bet end up stuck at $0. In the brainCloud portal, go to **Design > Cloud Data > Global Properties** and add each of these (names must match exactly — see `lib/main.dart`):

| Property name | Purpose |
|---|---|
| `QuickBet1` | First quick-bet amount; also used as the starting bet each hand |
| `QuickBet2` | Second quick-bet amount |
| `QuickBet3` | Third quick-bet amount |
| `QuickBet4` | Fourth quick-bet amount |
| `QuickBetMax` | Largest quick-bet amount |
| `AddFreeMoney` | Amount of free currency granted to a player |
| `JackpotCut` | Portion of a lost bet that feeds the jackpot (a "post" or a loss both contribute) |
| `JackpotDefaultValue` | Value the jackpot resets to once a player collects it |
| `StreakToWinJackpot` | Consecutive wins (a "post" or a win both count) needed to collect the jackpot |

Pick whatever numeric values suit your desired game balance — just make sure each is set to a plain integer value, since the app parses them with `int.parse`.

### Adding the global statistics

Separately from per-player stats, this sample also tracks app-wide totals with brainCloud Global Statistics via `globalStatisticsService.incrementGlobalStats()`. In the brainCloud portal, go to **Design > Cloud Data > Global Statistics** and add each of these as an **Integer** stat with a default value of `0` (names must match exactly — see `lib/main.dart`):

| Stat name | Tracks |
|---|---|
| `GamesPlayed` | Total hands played across all players |
| `Jackpot` | Current pooled jackpot amount |
| `TotalHouseWinnings` | Total amount kept by the house |
| `TotalJackpotWinnings` | Total amount fed into the jackpot |
| `StreakOf00`, `StreakOf01`, … `StreakOf09`, `StreakOf10`, `StreakOf11`, … | Distribution of win-streak lengths when a streak ends — the stat name is built at runtime as `"StreakOf" + currentWinStreak` (zero-padded below 10), so there's no fixed upper bound; add buckets as high as you expect streaks to realistically go |

⚠️ `updateCurrentWinStreak()` in `lib/main.dart` is currently an empty stub, so `currentWinStreak` never actually increments — in practice only `StreakOf00` is ever hit today. `StreakOf01`+ only start getting used once that stub is implemented.

### Adding the cloud code scripts

Betting is settled server-side by two cloud code scripts that award/consume a `bucks` virtual currency, called via `scriptService.runScript()` (see `lib/main.dart` `awardCurrency()` / `consumeCurrency()`). See the header comments in [`cloud_code/AwardCurrency.ccjs`](cloud_code/AwardCurrency.ccjs) and [`cloud_code/ConsumeCurrency.ccjs`](cloud_code/ConsumeCurrency.ccjs) for the one-time portal setup:
* Design > Marketplace > Virtual Currencies — create a currency with ID `bucks`.
* Design > Cloud Code > Scripts — upload both scripts under those exact names (`AwardCurrency`, `ConsumeCurrency`), `clientCallable: true`, `s2sCallable: false`, `scriptTimeout: 20`.

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
