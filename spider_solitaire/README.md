# spider_solitaire

A simple card game that uses brainCloud as a backend. 

## Getting Started

1.	Clone the Repository:
```shell
git clone https://github.com/getbraincloud/examples-dart.git
```

2.	Navigate to the bc_chat Directory:
```shell
cd examples-dart/spider_solitaire
```

3.	Install Dependencies:
```shell
flutter pub get
```

4.	Configure brainCloud:
* Obtain your brainCloud app credentials from the brainCloud portal.
* Update the launch parameters MY_APPID and MY_SECRET with your App Id and App Secret.
* BrainCloudConfig reads these: 
```dart
    static const String appId = String.fromEnvironment('APPID');
    static const String serverSecret = String.fromEnvironment('APPSECRET');
```
	
5.	Run the Application:
```shell
flutter run  --dart-define=APPID=MY_APPID --dart-define=APPSECRET=MY_SECRET
```