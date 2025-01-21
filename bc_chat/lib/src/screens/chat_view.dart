import 'dart:async';

import 'package:bc_chat/src/model/channel.dart';
import 'package:bc_chat/src/model/message.dart';
import 'package:braincloud/braincloud.dart';
import 'package:flutter/material.dart';

/// Displays detailed information about a SampleItem.
class ChatView extends StatefulWidget {
  final Channel channel;

  const ChatView({super.key, required this.channel, required this.bcWrapper});

  static const routeName = '/chat_view';
  final BrainCloudWrapper bcWrapper;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  List<Message> messages = [];
  final TextEditingController _chatController = TextEditingController();
  final int _defaultUpdateIntervalms = 500;
  Timer? _monitorTimer;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // super.didChangeDependencies();
    debugPrint(" ----------  didChangeAppLifecycleState:  $state --------");

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        debugPrint("App is pausing stop updates");
        _setMonitoringInterval(0);
        break;
      case AppLifecycleState.inactive:
        debugPrint("App is hidden slow down update");
        _setMonitoringInterval(_defaultUpdateIntervalms * 3);
        break;
      case AppLifecycleState.resumed:
        debugPrint("App is active again restore updates");
        _setMonitoringInterval(_defaultUpdateIntervalms);
        break;
      default:
        debugPrint("App is unknown will restore updates");
        _setMonitoringInterval(_defaultUpdateIntervalms);
    }
  }

  @override
  void deactivate() {
    if (_monitorTimer != null) _monitorTimer?.cancel();
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _fetchData();
      _setMonitoringInterval(_defaultUpdateIntervalms);
    }
  }

  void _joinChannel() async {
    if (!mounted) return;
    widget.bcWrapper.chatService.channelConnect(channelId: widget.channel.id, maxToReturn: 50).then((response) {
      if (response.statusCode == 200 && response.data != null) {
        if (!mounted) return;
        debugPrint(" We did get messages $response  ${response.data}");
        List<dynamic> msgs = response.data?['messages'];
        List<Message> loadedMessage = [];
        for (var m in msgs) {
          loadedMessage.add(Message.fromMap(m));
        }
        setState(() {
          messages = loadedMessage;
        });
      }
    });
  }
  void _fetchData() async {
    if (!mounted) return;
    widget.bcWrapper.chatService.getRecentChatMessages(channelId: widget.channel.id, maxReturn: 50).then((response) {
      if (response.statusCode == 200 && response.data != null) {
        if (!mounted) return;
        debugPrint(" We did get messages $response  ${response.data}");
        List<dynamic> msgs = response.data?['messages'];
        List<Message> loadedMessage = [];
        for (var m in msgs) {
          loadedMessage.add(Message.fromMap(m));
        }
        setState(() {
          messages = loadedMessage;
        });
      }
    });
  }

  void _setMonitoringInterval(int interval) {
    if (_monitorTimer != null) _monitorTimer?.cancel();
    if (interval == 0) return; // stopping the timer.
    _monitorTimer = Timer.periodic(Duration(milliseconds: interval), (Timer t) {
      if (t.isActive) _fetchData();
    });
  }

  ListTile _makeTile(Message msg) {
    if (msg.from.id == widget.bcWrapper.brainCloudClient.profileId) {
      return ListTile(
        title: Text(
          msg.content.text,
          textAlign: TextAlign.end,
        ),
        titleAlignment: ListTileTitleAlignment.bottom,
        trailing: msg.from.getAvatar(),
      );
    }
    return ListTile(
      title: Text(msg.content.text),
      leading: msg.from.getAvatar(),
    );
  }

  void _handleMessage() {
    if (_chatController.text.isNotEmpty) {
      String msg = _chatController.text;
      bool saveHistory = true;
      if (msg.startsWith("/me")) {
        msg = "${msg.replaceFirst("/me", "_[no history] ")}_";
        saveHistory = false;
      }
      widget.bcWrapper.chatService.postChatMessageSimple(channelId: widget.channel.id, chatMessage: msg, recordInHistory: saveHistory).then((response) {
        if (response.statusCode == 200) {
          _chatController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(widget.channel.name),
              Text(
                widget.channel.desc,
                textScaler: const TextScaler.linear(0.6),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                restorationId: 'chatView',
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  Message msg = messages[index];

                  return _makeTile(msg);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _chatController,                
                decoration: InputDecoration(
                  suffix: IconButton(onPressed: _handleMessage, icon: const Icon(Icons.send)),
                    border: const OutlineInputBorder(),
                    // labelText: 'password',                    
                    hintText: 'Enter text here - /me Message that will not persist in history'),
                onEditingComplete: _handleMessage,
              ),
            ),
          ],
        ));
  }
}
