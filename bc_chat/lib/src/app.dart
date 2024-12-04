import 'package:bc_chat/src/model/channel.dart';
import 'package:bc_chat/src/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:braincloud_dart/braincloud_dart.dart';

import 'screens/chat_view.dart';
import 'screens/channel_list_view.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;
  final BrainCloudWrapper _bc = BrainCloudWrapper();
  final String appId = const String.fromEnvironment("APPID", defaultValue: "");
  final String secretKey = const String.fromEnvironment("APPSECRET", defaultValue: "");
  final String serverUrl = const String.fromEnvironment("SERVERURL", defaultValue: "");

  void initBc() {
    if (!_bc.isInitialized) {
      debugPrint("Will init with app id $appId at $serverUrl");
      _bc.init(secretKey: secretKey, appId: appId, version: "1.0.0", updateTick: 50, url: serverUrl);
    }
  }



  @override
  Widget build(BuildContext context) {
    initBc();
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {        
        return MaterialApp(
          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'app',

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          onGenerateTitle: (BuildContext context) => AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: ThemeData(),
          darkTheme: ThemeData.dark(),
          themeMode: settingsController.themeMode,

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {
                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);
                  case ChatView.routeName:
                    return ChatView(bcWrapper: _bc, channel: Channel.fromMap(routeSettings.arguments as Map<String,dynamic>) );
                  case ChannelListView.routeName:
                    return ChannelListView(
                      bcWrapper: _bc,
                    );
                  case LoginScreen.routeName:
                  default:
                    return LoginScreen(bcWrapper: _bc);
                }
              },
            );
          },
        );
      },
    );
  }
}
