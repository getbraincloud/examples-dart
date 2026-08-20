import 'package:flutter/foundation.dart';

/// Reactive state for the Flutter overlays (toolbar + stat grid) drawn on top
/// of the Flame game canvas. MyGame mutates these fields then calls [refresh].
class GameHud extends ChangeNotifier {
  String title = "Acey Deucey";
  String username = "";
  String clientVersion = "";

  // -1 means "not loaded yet" so the empty-balance check in newHand() doesn't
  // fire before the player's real balance has been fetched.
  int money = -1;
  int bet = 0;
  String gameStatusMsg = "";

  int currentWinStreak = 0;
  int currentJackpot = 0;
  int streakToWinJackpot = 0;

  int quickBet1 = 0;
  int quickBet2 = 0;
  int quickBet3 = 0;
  int quickBet4 = 0;
  int quickBetMax = 0;
  int freeMoneyAmount = 0;

  /// True when the player is allowed to change their bet (i.e. before a card
  /// has been dealt for the current hand).
  bool canBet = true;

  void refresh() => notifyListeners();
}
