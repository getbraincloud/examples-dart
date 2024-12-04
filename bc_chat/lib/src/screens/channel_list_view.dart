import 'package:bc_chat/src/model/channel.dart';
import 'package:braincloud_dart/braincloud_dart.dart';
import 'package:flutter/material.dart';

import '../settings/settings_view.dart';
import 'chat_view.dart';


/// Displays a list of SampleItems.
class ChannelListView extends StatefulWidget {
  const ChannelListView({
    super.key,
    required this.bcWrapper
  });

  static const routeName = '/channels';

  final BrainCloudWrapper bcWrapper;


  @override
  State<ChannelListView> createState() => _ChannelListViewState();
}

class _ChannelListViewState extends State<ChannelListView> {

  // List<dynamic>? channels;
  List<Channel>? channels;

  void loadChannels() async {
    ServerResponse response = await widget.bcWrapper.chatService.getSubscribedChannels(channeltype: 'gl');
    if (response.statusCode == 200 && response.data != null) {
      // debugPrint('Channels are ${response.data}');
      List<dynamic> chnls = response.data?['channels'];
      List<Channel> loadedChannels = [];
      for (var c in chnls) {
        loadedChannels.add(Channel.fromMap(c));
      }
      loadedChannels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        channels = loadedChannels;
      });
    }
  }

void _onLogout() {
  widget.bcWrapper.resetStoredAnonymousId();
  widget.bcWrapper.resetStoredProfileId();
  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    
    if (channels == null) loadChannels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
        leading: IconButton(onPressed: _onLogout, icon: const Icon(Icons.logout)),
      ),

      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: (channels == null) ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        // Providing a restorationId allows the ListView to restore the
        // scroll position when a user leaves and returns to the app after it
        // has been killed while running in the background.
        restorationId: 'channelListView',
        itemCount: channels?.length,
        itemBuilder: (BuildContext context, int index) {
          Channel item = channels![index];

          return ListTile(
            title: Text(item.name),
            leading: const CircleAvatar(
              // Display the Flutter Logo image asset.
              foregroundImage: AssetImage('assets/images/flutter_logo.png'),
            ),
            onTap: () {
              // Navigate to the details page. If the user leaves and returns to
              // the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(
                context,
                ChatView.routeName,
                arguments: item.toMap()
              );
            }
          );
        },
      ),
    );
  }
}
