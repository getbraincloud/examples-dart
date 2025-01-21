# bc_chat

bc_chat is a Flutter-based example application demonstrating the integration of brainCloud’s chat features. This sample app showcases how to implement real-time chat functionalities using the brainCloud backend services.

## Features

* User Authentication: Authenticate users securely with brainCloud.
* Real-time Messaging: Send and receive messages instantly.
* Chat Channels: Support for multiple chat channels.
* Message History: Retrieve and display past messages.
* Support long running sessions ("_Remember me_")

## Prerequisites

Before running the application, ensure you have the following installed:
* Dart SDK
* Flutter SDK
* Enable Chat in brainCloud portal (Design->Messaging->Chat)

## Getting Started

1.	Clone the Repository:
```shell
git clone https://github.com/getbraincloud/examples-dart.git
```

2.	Navigate to the bc_chat Directory:
```shell
cd examples-dart/bc_chat
```

3.	Install Dependencies:
```shell
flutter pub get
```

4.	Configure brainCloud:
* Obtain your brainCloud app credentials from the brainCloud portal.
* Update the launch parameters MY_APPID and MY_SECRET with your App Id and App Secret.
	
5.	Run the Application:
```shell
flutter run  --dart-define=APPID=MY_APPID --dart-define=APPSECRET=MY_SECRET
```

