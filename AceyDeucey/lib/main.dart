import 'dart:async';
import 'dart:math';

import 'package:braincloud/braincloud.dart';
import 'package:braincloud_data_persistence/braincloud_data_persistence.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:sample_app/game_button.dart';
import 'card_component.dart';

final _bcWrapper = BrainCloudWrapper(wrapperName: "flutter_sample_app",persistence: DataPersistence() );

String channelId = "";

int money = 0;

String? userId;

const routeHome = '/home';
const routeSignIn = '/signIn';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const MyApp());

///Main App
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  dispose() {
    _bcWrapper.onDestroy();
    super.dispose();
  }

  /// Future to init the BrainCloud Client
  Future<String> _initAndUpdateRoute() async {
    const secretKey = String.fromEnvironment('secretKey');
    if (secretKey.isEmpty) {
      throw AssertionError(
          'secretKey is not set. Create a bc_config.json and run with --dart-define-from-file=bc_config.json');
    }

    const appId = String.fromEnvironment('appId');
    if (appId.isEmpty) {
      throw AssertionError(
          'appId is not set. Create a bc_config.json and run with --dart-define-from-file=bc_config.json');
    }

    const version = String.fromEnvironment('version');
    if (version.isEmpty) {
      throw AssertionError(
          'version is not set. Create a bc_config.json and run with --dart-define-from-file=bc_config.json');
    }

    const url = String.fromEnvironment('url');
    // if (url.isEmpty) {
    //   throw AssertionError(
    //       'url is not set. Create a bc_config.json and run with --dart-define-from-file=bc_config.json');
    // }

    channelId = "$appId:gl:jackpot";

    await _bcWrapper.init(
        secretKey: secretKey,
        appId: appId,
        version: version,
        url: url.isNotEmpty ? url :null,
        updateTick: 50);

    /// Check if there was a session
    bool hadSession = _bcWrapper.canReconnect();

    if (hadSession) {
      _bcWrapper.reconnect();
    }

    ///return the route name base on existing session
    return Future<String>.delayed(
        Duration.zero, () => hadSession ? routeHome : routeSignIn);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initAndUpdateRoute(),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          Widget page = Container();
          if (snapshot.hasData) {
            page = MaterialApp(
              navigatorKey: navigatorKey,
              routes: {
                routeHome: (context) => const HomePage(),
                routeSignIn: (context) => const SignInPage()
              },
              initialRoute: snapshot.data,
            );
          } else if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasError) {
            /// Display error
            page = Text(snapshot.error.toString());
          }

          return page;
        });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GameWidget(game: MyGame(), overlayBuilderMap: {
      "SignOutButton": (context, game) => Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                    onPressed: () async {
                      await _bcWrapper.logout();
                      navigatorKey.currentState
                          ?.pushReplacementNamed(routeSignIn);
                    },
                    child: const Text("Sign out")),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                    onPressed: null,
                    child: Text("Test")),
              ),
            ],
          )
    }));
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          color: Colors.amber,
          child: Form(
            key: _formKey,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 100, maxWidth: 400),
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(), labelText: "Email"),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),
                      Container(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: "Password"),
                        obscureText: true,
                        onFieldSubmitted: (_) => signIn(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      Container(height: 12),
                      ElevatedButton(
                          onPressed: () => signIn(context),
                          child: const Text("Sign In"))
                    ]),
              ),
            ),
          )),
    );
  }

  signIn(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      ServerResponse response = await _bcWrapper.authenticateEmailPassword(
          email: emailController.text,
          password: passwordController.text,
          forceCreate: true);

      if (response.statusCode == StatusCodes.ok) {
        navigatorKey.currentState?.pushReplacementNamed(routeHome);

        userId = response.data?["id"];
      } else {
        if (response.reasonCode == ReasonCodes.invalidPacketId) {
          // Should just retry sending the message. 
        }
        if (context.mounted) {
          debugPrint("Error: $response");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An error occured')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill input')),
      );
    }
  }
}

class MyGame extends FlameGame with TapDetector {
  SpriteComponent spLogo = SpriteComponent();

  CardComponent card1 = CardComponent();
  CardComponent card2 = CardComponent();
  CardComponent card3 = CardComponent();

  TextComponent gameStatusMsg = TextComponent(position: Vector2(150, 150));

  TextComponent moneyText = TextComponent(position: Vector2(50, 65));

  GameButton mainButton = GameButton(
      iconPath: "images/Icon_Deck.svg", toggleIconPath: "images/Icon_Next.svg");

  final cards = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
  final suits = ["Diamonds", "Hearts", "Clubs", "Spades"];
  final deck = [];

  int bet = 1;
  int gamesLost = 0;
  int gamesWon = 0;
  int dollarsWon = 0;

  int quickBet1 = 0;
  int quickBet2 = 0;
  int quickBet3 = 0;
  int quickBet4 = 0;
  int quickBetMax = 0;

  List gameResults = [];
  int refills = 0;

  GameState state = GameState.deal;

  int currentWinStreak = 0;

  // Amount to be won when Jackpot is collected. *Hopefully* real-time- dependant on how polling is implemented
  int currentJackpot = 0;

  // Percent of bet that goes to the Jackpot. Both "POST" and "LOSS" contribute to this, but only "POST" counts as a loss for the Win Streak.
  int jackpotCut = 0;

  // Number of wins in a row required to collect the Jackpot. Both "POST" and "WIN" contribute to the streak.
  int streakToWinJackpot = 0;

  int freeMoneyAmount = 0;

  List currentCards = [];

  final double padding = 12;

  final regularTextStyle = TextPaint(
    style: TextStyle(fontSize: 48.0, color: BasicPalette.white.color),
  );

  final winTextStyle = TextPaint(
    style: TextStyle(fontSize: 48.0, color: BasicPalette.green.color),
  );

  MyGame();

  @override
  Color backgroundColor() => Color(0xFF333333);

  @override
  FutureOr<void> onLoad() async {
    for (String suit in suits) {
      for (int card in cards) {
        deck.add(PlayingCard(value: card, suit: suit));
      }
    }

    spLogo
      ..sprite = await loadSprite("AD_bcLogo_dark.png")
      ..size = Vector2(100, 109)
      ..x = size[0] - 130
      ..y = padding;

    add(spLogo);

    card1
      ..x = (size[0] / 2) - 180
      ..y = (size[1] / 2) - 300;

    await add(card1);

    card2
      ..x = (size[0] / 2) + 20
      ..y = (size[1] / 2) - 300;

    await add(card2);

    card3
      ..x = (size[0] / 2) - 80
      ..y = (size[1] / 2) - 100;

    await add(card3);

    newHand();

    ServerResponse response =
        await _bcWrapper.globalAppService.readProperties();

    if (response.statusCode == StatusCodes.ok) {
      try {
        streakToWinJackpot =
            int.parse(response.data?["StreakToWinJackpot"]["value"]);

        freeMoneyAmount = int.parse(response.data?["AddFreeMoney"]["value"]);

        quickBet1 = int.parse(response.data?["QuickBet1"]["value"]);
        quickBet2 = int.parse(response.data?["QuickBet2"]["value"]);
        quickBet3 = int.parse(response.data?["QuickBet3"]["value"]);
        quickBet4 = int.parse(response.data?["QuickBet4"]["value"]);
        quickBetMax = int.parse(response.data?["QuickBetMax"]["value"]);

        bet = quickBet1;

        jackpotCut = int.parse(response.data?["JackpotCut"]["value"]);
      } catch (e) {
        debugPrint("$e");
      }
    }

    updateUserBalance();

    moneyText.text = "Balance: \$$money";
    add(moneyText);

    mainButton.onPressed = () => deal();
    mainButton.position = Vector2((size[0] / 2) - 40, (size[1] / 2) + 110);
    add(mainButton);

    gameStatusMsg.textRenderer = regularTextStyle;
    add(gameStatusMsg);

    overlays.add("SignOutButton");

    await super.onLoad();
  }

  newHand() async {
    mainButton.toggled = false;
    currentCards = List.from(deck);

    PlayingCard t1;
    PlayingCard t2;

    do {
      t1 = randomCard();
      t2 = randomCard();
    } while ((t1.value == t2.value) || ((t1.value - t2.value).abs() == 1));

    var values = [t1, t2];
    values.sort((a, b) => a.value.compareTo(b.value));

    card1.cardValue(values[0]);
    card2.cardValue(values[1]);
    card3.cardValue(PlayingCard(value: 0, suit: ""));

    gameStatusMsg.text = "";
  }

  deal() {
    if (mainButton.toggled) {
      newHand();
      return;
    }
    mainButton.toggled = true;

    var card = randomCard();
    card3.cardValue(card);

    Map<String, dynamic> incrementData = {};

    if (card3.value > card1.value && card3.value < card2.value) {
      debugPrint("WIN - In between the cards");

      int winAmount = (bet * 1.5).toInt();

      gameStatusMsg.textRenderer = winTextStyle;
      gameStatusMsg.text = "You won: \$$winAmount";

      gamesWon++;
      dollarsWon += winAmount;
      incrementData["Wins"] = 1;
      incrementData["DollarsWon"] = winAmount;

      gameResults.add(true);

      awardCurrency((winAmount) - bet);

      updateCurrentWinStreak();
    } else if (card3.value == card1.value || card3.value == card2.value) {
      debugPrint("LOSS - Same as high or low card");

      gameStatusMsg.textRenderer = regularTextStyle;
      gameStatusMsg.text = "You Lost!";

      gamesLost++;

      incrementData["Posts"] = 1;
      incrementData["Losses"] = 1;

      gameResults.add(false);

      consumeCurrency(bet);

      // Reset win streak and update global stats (track average streak achieved by user)
      resetStreak();
    } else {
      debugPrint("WIN - Outside the cards");
       int winAmount = (bet * 0.5).toInt();

      gameStatusMsg.textRenderer = winTextStyle;
      gameStatusMsg.text = "You Won: \$$winAmount";

      gamesWon++;
      dollarsWon += winAmount;
      incrementData["Wins"] = 1;
      incrementData["DollarsWon"] = winAmount;

      gameResults.add(false);

      consumeCurrency(winAmount);

      updateCurrentWinStreak();
    }

    _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: {"GamesPlayed": 1});

    _bcWrapper.playerStatisticsService.incrementUserStats(statistics: incrementData);

    _bcWrapper.socialLeaderboardService.postScoreToLeaderboard(
        leaderboardId: "AceyDeucyPlayers",
        score: dollarsWon,
        data: {"DollarsWon": dollarsWon, "Refills": refills});
  }

  PlayingCard randomCard() {    
    var rnd = Random();
    if (currentCards.isEmpty) throw ("Card Deck is empty"); 
    int position = rnd.nextInt(currentCards.length);

    var card = currentCards.removeAt(position);
    return card;
  }

  void updateJackpot(var amount) async {
    var statistics = {"Jackpot": amount};

    ServerResponse response = await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: statistics);

    if (response.statusCode == StatusCodes.ok) {
      var newJackpotAmount = response.data?["statistics"]["Jackpot"];

      // Jackpot should never be zero. When a player collects the jackpot, reset it to a default value (defined in Design > Cloud Data > Global Properties)
      if (newJackpotAmount == 0) {
        var defaultResetValue = 0;

        response = await _bcWrapper.globalAppService.readProperties();

        defaultResetValue = response.data?["JackpotDefaultValue"]["value"];

        updateJackpot(defaultResetValue);

        var statistics = {"TotalHouseWinnings": -1 * defaultResetValue};

        await _bcWrapper.globalStatisticsService
            .incrementGlobalStats(statistics: statistics);

        // Send updated Jackpot amount through Chat Channel
        var content = {"jackpotAmount": newJackpotAmount};

        var recordInHistory = true;

        await _bcWrapper.chatService.postChatMessage(
            channelId: channelId,
            contentJson: content,
            recordInHistory: recordInHistory);
      }
    }
  }

  resetStreak() async {
    String streakStat = "StreakOf";
    if (currentWinStreak < 10) {
      streakStat = "${streakStat}0";
    }
    streakStat = "$streakStat$currentWinStreak";

    Map<String, dynamic> statistics = {streakStat: 1};

    ServerResponse response = await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: statistics);

    var status = response.statusCode;
    debugPrint("$status  : $response");

    currentWinStreak = 0;
  }

  void awardCurrency(int amountToAward) {}

  void consumeCurrency(amountToConsume) async {
    var scriptName = "ConsumeCurrency";
    var vcAmount = amountToConsume;
    var scriptData = {"vcAmount": vcAmount};

    await _bcWrapper.scriptService
        .runScript(scriptName: scriptName, scriptData: scriptData);

    updateUserBalance();

    var newJpc = amountToConsume * jackpotCut;
    var houseCut = amountToConsume - jackpotCut;

    // User lost money, so Jackpot increases
    updateJackpot(amountToConsume * jackpotCut);

    // Increment TotalWinnings stat with for House and Jackpot
    var statistics = {
      "TotalJackpotWinnings": jackpotCut,
      "TotalHouseWinnings": houseCut
    };

    await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: statistics);
  }

  void updateUserBalance() async {
    var vcId = "bucks";

    ServerResponse response =
        await _bcWrapper.virtualCurrencyService.getCurrency(vcId: vcId);

    if (response.statusCode == StatusCodes.ok) {
      var newBalance = response.data?["currencyMap"]["bucks"]["balance"];

      money = newBalance;
      moneyText.text = "Balance: \$$money";
    } else {
      handleError(response);
    }
  }

  updateCurrentWinStreak() {}

  @override
  void onDispose() {
    _bcWrapper.onDestroy();
    super.onDispose();
  }

  handleError(ServerResponse response) {
    switch (response.reasonCode) {
      case ReasonCodes.playerSessionExpired:
        _bcWrapper.logout();
        navigatorKey.currentState
            ?.pushReplacementNamed(routeSignIn, result: "Session Expired");

        break;
      default:
        debugPrint("$response");
    }
  }
}

class PlayingCard {
  int value;
  String suit;

  PlayingCard({required this.value, required this.suit});
}

enum GameState { deal, newHand }
