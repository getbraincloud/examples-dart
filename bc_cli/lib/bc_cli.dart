import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bc_cli/file_persistence.dart';
import 'package:braincloud/braincloud.dart';

class Params {
  String appSecret = "";
  String appId = "";
  String user = "";
  String password = "";
  String? serverUrl;
  bool forceCreate = false;

  List<String> other = [];
}

Params parseArgs(List<String> args) {
  Params p = Params();
  int i = 0;
  while (i < args.length) {
    switch (args[i]) {
      case "--appid":
        if (i < args.length) p.appId = args[++i];
        break;
      case "--appsecret":
        if (i < args.length) p.appSecret = args[++i];
        break;
      case "--user":
        if (i < args.length) p.user = args[++i];
        break;
      case "--password":
        if (i < args.length) p.password = args[++i];
        break;
      case "--serverurl":
        if (i < args.length) p.serverUrl = args[++i];
        break;
      case "--force":
        if (i < args.length) p.forceCreate = true;
        break;
      default:
        p.other.add(args[i]);
    }
    i++;
  }
  return p;
}

void queryBraincloud(List<String> args) async {
  final bcWrapper = BrainCloudWrapper(wrapperName: "FlutterTest",persistence: FilePersistence());

  //  await Future.delayed(Duration(seconds: 3));

  Params params = parseArgs(args);

  print("appId     : ${params.appId}");
  print("appSecret : ${params.appSecret.isNotEmpty ? params.appSecret.replaceRange(3, null,  "*****-****-****-****-************") : "missing"}");
  if ((params.serverUrl ?? "").isNotEmpty ) ("serverUrl : ${params.serverUrl}");

  /// Initialize brainCloud client
  /// Be sure to have created the app in the your brainCloud account first.
  await bcWrapper
      .init(
          secretKey: params.appSecret,
          appId: params.appId,
          version: "0.0.1",
          url: params.serverUrl,
          updateTick: 50)
      .onError((error, stackTrace) {
    print(error.toString());
  });

  /// Get the server version and print it
  ServerResponse response = await bcWrapper.authenticationService.getServerVersion();
  print("Server Version   : ${response.data?['serverVersion']}");

  /// if a user argument is passed try to login to that user
  if (params.user.isNotEmpty) {
    print("user      : ${params.user}");
    print("password  : ${"".padLeft(params.password.length,"*")}");

    /// Login to the user and then show the results.
    response = await bcWrapper.authenticateEmailPassword(email: params.user, password: params.password, forceCreate: params.forceCreate);
    if (response.statusCode == 200) {
      String prettyJson = JsonEncoder.withIndent('  ').convert(response.data?['statistics']);
      print("User statistics $prettyJson");
    } else {
      print("User does not exits or could not be authenticated.");
      exit(1);
    }

  } else if (bcWrapper.canReconnect()) {
    /// Login anonymously
    response = await bcWrapper.authenticateAnonymous();
    if (response.statusCode == 200) {
      String prettyJson = JsonEncoder.withIndent('  ').convert(response.data?['statistics']);
      print(" -- used authenticateAnonymous to re-authentincation as -- ");
      print("user      : ${response.data?['emailAddress']}");

      print("User statistics $prettyJson");
    } else {
      print("User does not exits or could not be authenticated.");
      exit(1);
    }

  }
  /// We are down so stop the built-in run-loop to allow the app to terminate.
  bcWrapper.stopTimer();

}
