# bc_chat

bc_chat is a Flutter-based example application demonstrating the integration of brainCloud's chat features. This sample app showcases how to implement real-time chat functionalities using the brainCloud backend services.

## Features

* User Authentication: Authenticate users securely with brainCloud.
* Real-time Messaging: Send and receive messages instantly.
* Chat Channels: Support for multiple chat channels.
* Message History: Retrieve and display past messages.
* Support long running sessions ("_Remember me_")

## Prerequisites

See the [repository README](../README.md) for installing Flutter and creating a brainCloud app. This sample additionally needs:
* Chat enabled in the brainCloud portal (Design > Messaging > Chat)

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
