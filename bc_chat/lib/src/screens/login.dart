import 'package:bc_chat/src/screens/channel_list_view.dart';
import 'package:braincloud_dart/braincloud_dart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/';

  const LoginScreen({super.key, required this.bcWrapper});
  final BrainCloudWrapper bcWrapper;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final prefs = SharedPreferencesAsync();
  static const String kRememberMe = "RememberMe";

  String _errorMessage = "";
  bool rememberMe = false;
  bool loading = true;
  bool logingin = false;

  void loadState() async {
    if (loading) {
      rememberMe = (await prefs.getBool(kRememberMe)) ?? false;
      if (rememberMe) {
        _attemptReconnect();
      } else {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _attemptReconnect() {
    debugPrint("Reconnecting...");
    if (widget.bcWrapper.canReconnect()) {
      widget.bcWrapper.reconnect().then((response) {
        debugPrint("Reconnected response: $response");
        if (response.statusCode == 200 && mounted) {
          Navigator.restorablePushNamed(
            context,
            ChannelListView.routeName,
          );
        } else {
          setState(() {
            loading = false;
          });
        }
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  void _handleRememberMeCheckBox(bool? value) async {
    await prefs.setBool(kRememberMe, value ?? false);
    setState(() {
      rememberMe = value ?? false;
    });
  }

  void _handleLogin() async {
    setState(() {
      _errorMessage = "";
      logingin = true;
    });
    if (_userNameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      ServerResponse response =
          await widget.bcWrapper.authenticateUniversal(username: _userNameController.text, password: _passwordController.text, forceCreate: true);
      debugPrint("Resonse is $response");
      if (response.statusCode == 200) {
        setState(() {
          _errorMessage = "";
          logingin = false;
        });
        _passwordController.text = "";
        if (mounted) {
          Navigator.restorablePushNamed(
            context,
            ChannelListView.routeName,
          );
        }
      } else {
        setState(() {
          _errorMessage = response.error?['status_message'] ?? ((response.error is String) ? response.error : "Error");
          logingin = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = "Must provide both a user name and password.";
        logingin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    loadState();
    return Scaffold(
        appBar: AppBar(
          title: const Text('BC Chat'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Container(
                    alignment: Alignment.center,
                    child: SizedBox(
                        width: 350,
                        child: Column(
                          children: [
                            const Text(
                              "LOG IN",
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                            const Text("A new user will be created if it doesn't exist."),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextField(
                                controller: _userNameController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'username',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'password',
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(checkColor: Colors.white, value: rememberMe, onChanged: _handleRememberMeCheckBox),
                                const Text("Remember me"),
                                Expanded(
                                  child: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.all(4.0),
                                      child: ElevatedButton(onPressed: logingin ? null:_handleLogin, child: const Text("Login"))),
                                ),
                              ],
                            ),
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(_errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                    )),
                              )
                          ],
                        ))),
              ));
  }
}
