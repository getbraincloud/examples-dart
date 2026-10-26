# brainCloud Dart / Flutter Examples

This repository contains example Flutter projects that use the [brainCloud Dart client](https://github.com/getbraincloud/braincloud-dart). This is a good place to start learning how the various brainCloud APIs can be used.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.38 or later (Dart 3.10), required by the brainCloud 6.1 client
- A brainCloud account — sign up at the [brainCloud portal](https://portal.braincloudservers.com/). You can pick or create an app during setup.

## Configuring a sample

None of these samples ship with credentials. Each one reads its connection info from a `bc_config.json` in the sample's root folder, written by the brainCloud setup tool:

```shell
cd <SampleName>
flutter pub get
dart run braincloud:setup
```

This opens the brainCloud setup page in your browser. Log in, pick (or create) your app, and it writes `bc_config.json` and adds it to `.gitignore`. The samples then call `init()` with no parameters, which reads the config passed with `--dart-define-from-file`.

Point every sample at its own brainCloud app — don't reuse one app across samples.

## Samples

| Sample | Description |
|---|---|
| [AceyDeucey](AceyDeucey/README.md) | Casino-style card betting game — bet on whether a drawn card falls between two others, with cloud code scripts settling the virtual currency. |
| [bc_chat](bc_chat/README.md) | Real-time chat demo built on brainCloud's Messaging service. |
| [spider_solitaire](spider_solitaire/README.md) | Spider Solitaire with anonymous auth, player stats, and a cloud code script for username claims. |

## Running a sample

```shell
flutter run --dart-define-from-file=bc_config.json
```

See each sample's README for anything specific to it (enabling Chat, uploading cloud code, etc).

---

For more on brainCloud, check out the [brainCloud Docs](https://getbraincloud.com/apidocs/) and the [Dart client repository](https://github.com/getbraincloud/braincloud-dart).
