# Acey Deucey

Acey Deucey is a casino-style game in which players bet on whether a drawn card will be between two others. In general, the greater the gap between the two cards, the higher a bet should be.

There are three outcomes when the third card is flipped:

- The card is between the other two. Win 1.5x bet.
- The card is outside the other two. Win 0.5x bet.
- The card matches one of the other two. Lose bet.

Unless the third card is between the other two (option 1) a portion of the money that is lost will contribute to the jackpot.


Acey Deucey demostrate usage of the Dart braincloud client sdk.

## Getting Started


Get the dependencies

```shell
flutter pub get
```

Create a bc_config.json file for your app 
```json
{
    "secretKey":"<app secret from brainCloud portal>",
    "appId": "<app id from brainCloud portal>",
    "version": "1.0.0"
}
```

Run the app
```shell
flutter run --dart-define-from-file=bc_config.json
```

