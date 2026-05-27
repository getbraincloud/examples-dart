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

4. Create a bc_config.json file for your app 
```json
{
    "secretKey":"<app secret from brainCloud portal>",
    "appId": "<app id from brainCloud portal>",
    "version": "1.0.0"
}
```

5. Run the app
```shell
flutter run --dart-define-from-file=bc_config.json
```