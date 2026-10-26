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

2. Run the brainCloud setup tool, log in, and pick (or create) your app. It writes `bc_config.json` to this folder:
```shell
dart run braincloud:setup
```

3. Run the app:
```shell
flutter run --dart-define-from-file=bc_config.json
```
