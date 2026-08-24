import 'dart:async';
import 'dart:math';

import 'package:braincloud/braincloud.dart';
import 'package:braincloud_data_persistence/braincloud_data_persistence.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:sample_app/game_button.dart';
import 'card_component.dart';
import 'game_hud.dart';
import 'leaderboard_page.dart';

final _bcWrapper = BrainCloudWrapper(
    wrapperName: "flutter_sample_app", persistence: DataPersistence());

const String leaderboardId = "AceyDeucyPlayers";

String channelId = "";

String? userId;
String username = "";
bool isNewUser = false;

const routeHome = '/home';
const routeSignIn = '/signIn';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const MyApp());

/// Records the results of a successful authentication/reconnect: stores the
/// profile id, and resolves the display name (falling back to the Universal
/// ID the player signed in with, if brainCloud doesn't have one yet).
Future<void> _syncLoginState(ServerResponse response,
    {String? universalId}) async {
  userId = response.data?["id"];

  isNewUser =
      response.data?["newUser"] == true || response.data?["newUser"] == "true";

  String? playerName = response.data?["playerName"] as String?;
  if ((playerName == null || playerName.isEmpty) &&
      universalId != null &&
      universalId.isNotEmpty) {
    await _bcWrapper.playerStateService.updateUserName(userName: universalId);
    username = universalId;
  } else {
    username = playerName ?? "";
  }
}

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

    const url = String.fromEnvironment('serverUrl');

    channelId = "$appId:gl:jackpot";

    await _bcWrapper.init(
        secretKey: secretKey,
        appId: appId,
        version: version,
        url: url.isNotEmpty ? url : null,
        updateTick: 50);

    /// Check if there was a session and, if so, resume it.
    bool hadSession = _bcWrapper.canReconnect();

    if (hadSession) {
      ServerResponse response = await _bcWrapper.reconnect();
      if (response.statusCode == StatusCodes.ok) {
        await _syncLoginState(response);
      } else {
        hadSession = false;
      }
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
            page = Directionality(
              textDirection: TextDirection.ltr,
              child: Text(snapshot.error.toString()),
            );
          }

          return page;
        });
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double designHeight = 950;

  // Created once and reused across every rebuild (LayoutBuilder's builder
  // re-runs on every resize, and re-running `MyGame()` there would spin up a
  // fresh FlameGame mid-resize, positioned for a stale size while the
  // overlays already reflect the current one).
  final MyGame _game = MyGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scale = constraints.maxHeight <= 0
              ? 1.0
              : (constraints.maxHeight / designHeight).clamp(0.05, 1.0);
          return OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth / scale,
                height: designHeight,
                child: GameWidget(
                  game: _game,
                  overlayBuilderMap: {
                    "Toolbar": (context, game) =>
                        _buildToolbar(context, game as MyGame),
                    "Grid": (context, game) =>
                        _buildGrid(context, game as MyGame),
                  },
                  initialActiveOverlays: const ["Toolbar", "Grid"],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildToolbar(BuildContext context, MyGame game) {
  return AnimatedBuilder(
    animation: game.hud,
    builder: (context, _) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: MyGame.topBarHeight,
        child: Container(
          color: Colors.indigo,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.leaderboard, color: Colors.white),
                tooltip: "Leaderboards",
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LeaderboardPage(
                        bcWrapper: _bcWrapper, userId: userId))),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: "Help",
                onPressed: () => game.showHelpDialog(),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    game.hud.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  game.hud.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: "Sign out",
                onPressed: () async {
                  await _bcWrapper.logout(forgetUser: true);
                  navigatorKey.currentState?.pushReplacementNamed(routeSignIn);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildGrid(BuildContext context, MyGame game) {
  return AnimatedBuilder(
    animation: game.hud,
    builder: (context, _) {
      final hud = game.hud;
      const labelStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
      final quickBets = [
        hud.quickBet1,
        hud.quickBet2,
        hud.quickBet3,
        hud.quickBet4,
      ];

      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: MyGame.bottomPanelHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                      child: Center(child: Text("BALANCE", style: labelStyle))),
                  Expanded(
                      child: Center(child: Text("BET", style: labelStyle))),
                  Expanded(
                      child: Center(child: Text("WIN", style: labelStyle))),
                  Expanded(
                      child: Center(
                          child: Text("CURRENT STREAK", style: labelStyle))),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child: Center(
                          child: Text("\$${hud.money < 0 ? 0 : hud.money}",
                              style: labelStyle))),
                  Expanded(
                      child: Center(
                          child: Text("\$${hud.bet}", style: labelStyle))),
                  Expanded(
                      child: Center(
                          child: Text(hud.gameStatusMsg, style: labelStyle))),
                  Expanded(
                      child: Center(
                          child: Text("${hud.currentWinStreak}",
                              style: labelStyle))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white),
                      onPressed: () => game.freeMoney(hud.freeMoneyAmount),
                      child: const Text("ADD VIRTUAL MONEY"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...quickBets.map((amount) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white),
                            onPressed: hud.canBet
                                ? () => game.customBetClick(amount)
                                : null,
                            child: Text("\$$amount"),
                          ),
                        ),
                      )),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white),
                      onPressed: hud.canBet
                          ? () => game.customBetClick(hud.quickBetMax)
                          : null,
                      child: const Text("MAX"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text("brainCloud Client Version: ${hud.clientVersion}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    },
  );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController universalIdController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool signingIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text(
          "Acey Deucey",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 100, maxWidth: 400),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Acey Deucey",
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          Container(height: 24),
                          TextFormField(
                            controller: universalIdController,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Universal ID"),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your Universal ID';
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
                          const Text(
                              "If there is no account tied to the given Universal ID, a new one will be auto-created using the password you enter.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                          Container(height: 12),
                          signingIn
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                  ),
                                  onPressed: () => signIn(context),
                                  child: const Text("Login")),
                          Container(height: 12),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () => {},
                              child: const Text("Forgot Password")),
                        ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  signIn(BuildContext context) async {
    if (signingIn) return;

    if (_formKey.currentState!.validate()) {
      setState(() => signingIn = true);

      String universalId = universalIdController.text;

      ServerResponse response = await _bcWrapper.authenticateUniversal(
          username: universalId,
          password: passwordController.text,
          forceCreate: true);

      if (response.statusCode == StatusCodes.ok) {
        await _syncLoginState(response, universalId: universalId);
        navigatorKey.currentState?.pushReplacementNamed(routeHome);
      } else {
        setState(() => signingIn = false);

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
  static const double topBarHeight = 64;
  static const double bottomPanelHeight = 180;

  CardComponent card1 = CardComponent();
  CardComponent card2 = CardComponent();
  CardComponent card3 = CardComponent();

  TextComponent jackpotText = TextComponent(anchor: Anchor.topRight);
  TextComponent jackpotStreakText = TextComponent(anchor: Anchor.topRight);

  GameButton mainButton = GameButton(
      iconPath: "images/Icon_Deck.svg", toggleIconPath: "images/Icon_Next.svg");

  TextComponent stateLabelText = TextComponent(anchor: Anchor.topCenter);

  final hud = GameHud();

  final cards = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
  final suits = ["Diamonds", "Hearts", "Clubs", "Spades"];
  final deck = [];

  int bet = 1;
  int gamesLost = 0;
  int gamesWon = 0;
  int dollarsWon = 0;

  List gameResults = [];
  int refills = 0;

  int currentWinStreak = 0;

  // Amount to be won when Jackpot is collected.
  int currentJackpot = 0;

  // Fraction of bet that goes to the Jackpot (e.g. 0.1 for 10%). Both "POST" and "LOSS" contribute to this, but only "POST" counts as a loss for the Win Streak.
  double jackpotCut = 0;

  // Number of wins in a row required to collect the Jackpot. Both "POST" and "WIN" contribute to the streak.
  int streakToWinJackpot = 0;

  List currentCards = [];

  final double padding = 12;

  final int cardFlipDurationMs = 300;
  final int resultMessageDelayms = 600;

  final regularTextStyle = TextPaint(
    style: TextStyle(fontSize: 48.0, color: BasicPalette.white.color),
  );

  final winTextStyle = TextPaint(
    style: TextStyle(fontSize: 48.0, color: BasicPalette.green.color),
  );

  final jackpotTextStyle = TextPaint(
    style: const TextStyle(
        fontSize: 28.0, fontWeight: FontWeight.bold, color: Colors.indigo),
  );

  final jackpotStreakTextStyle = TextPaint(
    style: const TextStyle(fontSize: 18.0, color: Colors.grey),
  );

  final stateLabelTextStyle = TextPaint(
    style: const TextStyle(
        fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.indigo),
  );

  MyGame();

  @override
  Color backgroundColor() => Color(0xFFFFFFFF);

  /// Positions the board's components from the current canvas [size].
  /// Called once from [onLoad] and again from [onGameResize] since width
  /// tracks the real window (see [_HomePageState.build]) and can change
  /// after load, while height is fixed at design time.
  void _layoutComponents() {
    final double bandTop = topBarHeight + 20;
    final double cardsRowY = bandTop + 70;

    card1
      ..x = (size[0] / 2) - 180
      ..y = cardsRowY;

    card2
      ..x = (size[0] / 2) + 20
      ..y = cardsRowY;

    card3
      ..x = (size[0] / 2) - 80
      ..y = cardsRowY + 200;

    jackpotText
      ..x = size[0] - padding
      ..y = bandTop;

    jackpotStreakText
      ..x = size[0] - padding
      ..y = bandTop + 36;

    mainButton.position = Vector2((size[0] / 2) - 40, cardsRowY + 420);
    stateLabelText.position = Vector2(size[0] / 2, cardsRowY + 508);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _layoutComponents();
    }
  }

  @override
  FutureOr<void> onLoad() async {
    for (String suit in suits) {
      for (int card in cards) {
        deck.add(PlayingCard(value: card, suit: suit));
      }
    }

    _layoutComponents();

    await add(card1);
    await add(card2);
    await add(card3);

    jackpotText.textRenderer = jackpotTextStyle;
    add(jackpotText);

    jackpotStreakText.textRenderer = jackpotStreakTextStyle;
    add(jackpotStreakText);

    newHand();

    ServerResponse response =
        await _bcWrapper.globalAppService.readProperties();

    if (response.statusCode == StatusCodes.ok) {
      try {
        streakToWinJackpot =
            int.parse(response.data?["StreakToWinJackpot"]["value"]);

        hud.freeMoneyAmount =
            int.parse(response.data?["AddFreeMoney"]["value"]);

        hud.quickBet1 = int.parse(response.data?["QuickBet1"]["value"]);
        hud.quickBet2 = int.parse(response.data?["QuickBet2"]["value"]);
        hud.quickBet3 = int.parse(response.data?["QuickBet3"]["value"]);
        hud.quickBet4 = int.parse(response.data?["QuickBet4"]["value"]);
        hud.quickBetMax = int.parse(response.data?["QuickBetMax"]["value"]);

        bet = hud.quickBet1;
      } catch (e) {
        debugPrint("$e");
      }

      try {
        jackpotCut = double.parse(response.data?["JackpotCut"]["value"]);
      } catch (e) {
        debugPrint("$e");
      }
    }

    hud.title = "Acey Deucey";
    hud.username = username;
    hud.streakToWinJackpot = streakToWinJackpot;
    hud.clientVersion = _bcWrapper.brainCloudClient.brainCloudClientVersion;
    hud.bet = bet;
    hud.canBet = true;
    hud.refresh();

    // Fire these off together rather than awaiting each in turn — RTT
    // registration in particular needs to go out promptly after login
    // (see enableRTTAndConnect's retry comment).
    updateUserBalance();
    loadJackpot();
    enableRTTAndConnect();

    if (isNewUser) {
      isNewUser = false;
      awardCurrency(hud.freeMoneyAmount);
    } else {
      loadPlayerStats();
    }

    mainButton.onPressed = () => deal();
    add(mainButton);

    stateLabelText
      ..textRenderer = stateLabelTextStyle
      ..text = "Flip";
    add(stateLabelText);

    await super.onLoad();
  }

  newHand() async {
    mainButton.toggled = false;
    stateLabelText.text = "Flip";
    hud.canBet = true;
    currentCards = List.from(deck);

    PlayingCard t1;
    PlayingCard t2;

    do {
      t1 = randomCard();
      t2 = randomCard();
    } while ((t1.value == t2.value) || ((t1.value - t2.value).abs() == 1));

    var values = [t1, t2];
    values.sort((a, b) => a.value.compareTo(b.value));

    card1.cardValue(PlayingCard(value: 0, suit: ""));
    card1.cardValue(values[0]);
    Timer(Duration(milliseconds: cardFlipDurationMs), () {
      card2.cardValue(PlayingCard(value: 0, suit: ""));
      card2.cardValue(values[1]);
    });
    card3.cardValue(PlayingCard(value: 0, suit: ""));
    hud.bet = bet;
    hud.gameStatusMsg = "";
    hud.refresh();

    if (hud.money == 0) {
      showInsufficientFundsDialog();
    }
  }

  deal() {
    if (mainButton.toggled) {
      newHand();
      return;
    }

    if (bet > hud.money) {
      showInsufficientFundsDialog();
      return;
    }

    mainButton.toggled = true;
    stateLabelText.text = "Next Round";
    hud.canBet = false;

    var card = randomCard();
    card3.cardValue(card);

    Map<String, dynamic> incrementData = {};

    if (card3.value > card1.value && card3.value < card2.value) {
      debugPrint("WIN - In between the cards");

      int winAmount = (bet * 1.5).toInt();

      card3.setResultBorder(CardComponent.winBorderColor);

      hud.gameStatusMsg = "\$$winAmount";
      // gameStatusMsg.textRenderer = winTextStyle;
      // Async.Timer(Duration(milliseconds: resultMessageDelayms), () {
      //   gameStatusMsg.text = "You won: \$$winAmount";
      // });

      gamesWon++;
      dollarsWon += winAmount;
      incrementData["Wins"] = 1;
      incrementData["DollarsWon"] = winAmount;

      gameResults.add(true);

      awardCurrency((winAmount) - bet);

      updateCurrentWinStreak();
    } else if (card3.value == card1.value || card3.value == card2.value) {
      debugPrint("LOSS - Same as high or low card");

      card3.setResultBorder(CardComponent.postBorderColor);
      if (card1.value == card3.value) {
        card1.setResultBorder(CardComponent.postBorderColor);
      } else {
        card2.setResultBorder(CardComponent.postBorderColor);
      }

      hud.gameStatusMsg = "\$0";
      // gameStatusMsg.textRenderer = regularTextStyle;
      // Async.Timer(Duration(milliseconds: resultMessageDelayms), () {
      //   gameStatusMsg.text = "You Lost!";
      // });

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

      card3.setResultBorder(CardComponent.outsideWinBorderColor);

      hud.gameStatusMsg = "\$$winAmount";
      // gameStatusMsg.textRenderer = winTextStyle;
      // Async.Timer(Duration(milliseconds: resultMessageDelayms), () {
      //   gameStatusMsg.text = "You Won: \$$winAmount";
      // });

      gamesWon++;
      dollarsWon += winAmount;
      incrementData["Wins"] = 1;
      incrementData["DollarsWon"] = winAmount;

      gameResults.add(false);

      consumeCurrency(winAmount);

      updateCurrentWinStreak();
    }

    hud.refresh();

    _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: {"GamesPlayed": 1});

    _bcWrapper.playerStatisticsService
        .incrementUserStats(statistics: incrementData);

    _bcWrapper.socialLeaderboardService.postScoreToLeaderboard(
        leaderboardId: leaderboardId,
        score: dollarsWon,
        data: {"DollarsWon": dollarsWon, "Refills": refills});
  }

  /// Sets the bet for the next hand. Only allowed before a card is dealt.
  void customBetClick(int customBet) {
    bet = customBet;
    hud.bet = bet;
    hud.refresh();
  }

  PlayingCard randomCard() {
    var rnd = Random();
    if (currentCards.isEmpty) throw ("Card Deck is empty");
    int position = rnd.nextInt(currentCards.length);

    var card = currentCards.removeAt(position);
    return card;
  }

  /// Reads the current Jackpot Global Stat, resetting it to the default
  /// value defined in Global Properties if it has never been set.
  Future<void> loadJackpot() async {
    ServerResponse response =
        await _bcWrapper.globalStatisticsService.readAllGlobalStats();

    if (response.statusCode == StatusCodes.ok) {
      int currentJackpotAmount =
          ((response.data?["statistics"]?["Jackpot"] ?? 0) as num).toInt();

      if (currentJackpotAmount == 0) {
        ServerResponse propsResponse =
            await _bcWrapper.globalAppService.readProperties();

        int defaultResetValue =
            int.parse(propsResponse.data?["JackpotDefaultValue"]["value"]);

        await updateJackpot(defaultResetValue);

        await _bcWrapper.globalStatisticsService.incrementGlobalStats(
            statistics: {"TotalHouseWinnings": -1 * defaultResetValue});
      } else {
        updateDisplayedJackpot(currentJackpotAmount);
      }
    }
  }

  void updateDisplayedJackpot(int amount) {
    currentJackpot = amount;
    hud.currentJackpot = amount;
    jackpotText.text = "JACKPOT: \$$currentJackpot";
    jackpotStreakText.text = "$streakToWinJackpot-Streak to Win!";
    hud.refresh();
  }

  /// Increment the Jackpot if a user loses money (positive amount), or reset
  /// it to the default value when it is collected (pass a negative amount
  /// equal to the current Jackpot).
  Future<void> updateJackpot(int amount) async {
    ServerResponse response = await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: {"Jackpot": amount});

    if (response.statusCode == StatusCodes.ok) {
      int newJackpotAmount =
          ((response.data?["statistics"]["Jackpot"] ?? 0) as num).toInt();

      // Jackpot should never be zero. When a player collects the jackpot, reset it to a default value (defined in Design > Cloud Data > Global Properties)
      if (newJackpotAmount == 0) {
        ServerResponse propsResponse =
            await _bcWrapper.globalAppService.readProperties();

        int defaultResetValue =
            int.parse(propsResponse.data?["JackpotDefaultValue"]["value"]);

        await updateJackpot(defaultResetValue);

        await _bcWrapper.globalStatisticsService.incrementGlobalStats(
            statistics: {"TotalHouseWinnings": -1 * defaultResetValue});

        return;
      }

      updateDisplayedJackpot(newJackpotAmount);

      // Send updated Jackpot amount through Chat Channel so other connected
      // clients update their display too.
      await _bcWrapper.chatService.postChatMessage(
          channelId: channelId,
          contentJson: {"jackpotAmount": newJackpotAmount},
          recordInHistory: true);
    }
  }

  Future<void> collectJackpot() async {
    int amount = currentJackpot;

    awardCurrency(amount);

    await updateJackpot(-amount);

    resetStreak();

    await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: {"TimesJackpotCollected": 1});
  }

  /// Real-time Tech (RTT) must be checked on the dashboard, under
  /// Design | Core App Info | Advanced Settings.
  ///
  /// enableRTT occasionally fails right after login with reasonCode 40303
  /// (playerSessionExpired) — a transient race between the session created
  /// by authentication and the RTT connection registration seeing it. A
  /// single retry is enough since the session is valid moments later.
  void enableRTTAndConnect({bool isRetry = false}) {
    _bcWrapper.rttService.registerRTTChatCallback(_onRttChatMessage);

    _bcWrapper.rttService.enableRTT(
        successCallback: (_) => connectToGlobalChannels(),
        failureCallback: (error) {
          debugPrint("enableRTT Error: $error");
          if (!isRetry &&
              error.reasonCode == ReasonCodes.playerSessionExpired) {
            Timer(const Duration(seconds: 1),
                () => enableRTTAndConnect(isRetry: true));
          }
        });
  }

  void _onRttChatMessage(RTTCommandResponse rttResponse) {
    var jackpotAmount = rttResponse.data?["content"]?["jackpotAmount"];
    if (jackpotAmount != null) {
      updateDisplayedJackpot((jackpotAmount as num).toInt());
    }
  }

  Future<void> connectToGlobalChannels() async {
    ServerResponse response = await _bcWrapper.chatService
        .channelConnect(channelId: channelId, maxToReturn: 0);

    if (response.statusCode != StatusCodes.ok) {
      debugPrint("Failed to connect to $channelId channel");
    }
  }

  /// Increment the number of wins since last loss (only a "POST" counts as a loss)
  void updateCurrentWinStreak() {
    currentWinStreak++;
    hud.currentWinStreak = currentWinStreak;
    hud.refresh();

    if (currentWinStreak == streakToWinJackpot) {
      showCollectJackpotDialog();
    }
  }

  /// Increment the Global Stat for the current win streak and then reset the streak counter to zero.
  /// Only the stat of the current streak is incremented: 3 wins in a row increments ONLY "StreakOf3", not "StreakOf1" and "StreakOf2" as well.
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
    hud.currentWinStreak = 0;
    hud.refresh();
  }

  void awardCurrency(int amountToAward) async {
    var scriptName = "AwardCurrency";
    var vcAmount = amountToAward;
    var scriptData = {"vcAmount": vcAmount};
    await _bcWrapper.scriptService
        .runScript(scriptName: scriptName, scriptData: scriptData);

    updateUserBalance();

    await _bcWrapper.globalStatisticsService.incrementGlobalStats(
        statistics: {"TotalHouseWinnings": -1 * amountToAward});
  }

  void consumeCurrency(amountToConsume) async {
    var scriptName = "ConsumeCurrency";
    var vcAmount = amountToConsume;
    var scriptData = {"vcAmount": vcAmount};

    await _bcWrapper.scriptService
        .runScript(scriptName: scriptName, scriptData: scriptData);

    updateUserBalance();

    var jpCut = (amountToConsume * jackpotCut).toInt();
    var houseCut = amountToConsume - jpCut;

    // User lost money, so Jackpot increases
    updateJackpot(jpCut);

    // Increment TotalWinnings stat with for House and Jackpot
    var statistics = {
      "TotalJackpotWinnings": jpCut,
      "TotalHouseWinnings": houseCut
    };

    await _bcWrapper.globalStatisticsService
        .incrementGlobalStats(statistics: statistics);
  }

  /// Increase the user's balance for free (new user bonus, or the player
  /// running out of funds mid-session) and record the refill for the leaderboard.
  void freeMoney(int amount) {
    refills++;

    _bcWrapper.playerStatisticsService
        .incrementUserStats(statistics: {"Refills": 1});

    _bcWrapper.socialLeaderboardService.postScoreToLeaderboard(
        leaderboardId: leaderboardId,
        score: dollarsWon,
        data: {"DollarsWon": dollarsWon, "Refills": refills});

    awardCurrency(amount);
  }

  void updateUserBalance() async {
    var vcId = "bucks";

    ServerResponse response =
        await _bcWrapper.virtualCurrencyService.getCurrency(vcId: vcId);

    debugPrint(" :Player currency is :${response.data}");
    if (response.statusCode == StatusCodes.ok) {
      var newBalance = response.data?["currencyMap"]["bucks"]["balance"];

      hud.money = newBalance;
      hud.refresh();
      debugPrint("Updated balance is now :${hud.money}");
    } else {
      handleError(response);
    }
  }

  /// Seeds session totals (used when posting the leaderboard score) from the
  /// player's existing stats, so a returning player's score isn't understated
  /// by resetting to zero every session.
  Future<void> loadPlayerStats() async {
    ServerResponse response =
        await _bcWrapper.playerStatisticsService.readAllUserStats();

    if (response.statusCode == StatusCodes.ok) {
      var statistics = response.data?["statistics"];
      if (statistics != null) {
        gamesWon = ((statistics["Wins"] ?? 0) as num).toInt();
        gamesLost = ((statistics["Losses"] ?? 0) as num).toInt();
        refills = ((statistics["Refills"] ?? 0) as num).toInt();
        dollarsWon = ((statistics["DollarsWon"] ?? 0) as num).toInt();
      }
    }
  }

  Future<void> showHelpDialog() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    await showDialog(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
              title: const Text("Acey Deucey Rules"),
              content: const Text(
                  "Two cards are shown. The player chooses a bet value and then flips the third card. If the third card is between the first two, the player wins 1.5x their bet. If it is outside, the player wins half their bet. But if the third card matches either the first or second card, the bet is lost. The game also has a Jackpot. While in a session, each time the player wins their Current Streak increases. But each time the player loses their bet, their Current Streak is reset to zero. If the player reaches the Streak goal, the Jackpot is won."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Close"))
              ],
            ));
  }

  Future<void> showInsufficientFundsDialog() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    await showDialog(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
              title: const Text("Insufficient Funds"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Would you like to add more funds to your balance?"),
                  const SizedBox(height: 8),
                  const Text(
                      "This is a virtual transaction, no real money will be charged",
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    freeMoney(hud.freeMoneyAmount);
                  },
                  child: Text("Add \$${hud.freeMoneyAmount}"),
                ),
              ],
            ));
  }

  Future<void> showCollectJackpotDialog() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("JACKPOT WINNER!",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                  Text("${hud.streakToWinJackpot} GAMES IN A ROW!"),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      collectJackpot();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Collect \$${hud.currentJackpot}",
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ],
            ));
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
