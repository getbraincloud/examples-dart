# brainCloud Dart / Flutter Examples

This repository contains example Flutter projects that use the [brainCloud Dart client](https://github.com/getbraincloud/braincloud-dart). This is a good place to start learning how the various brainCloud APIs can be used.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (each sample's `pubspec.yaml` lists its minimum Dart SDK under `environment: sdk:`)
- A brainCloud app — sign up and create one at the [brainCloud portal](https://portal.braincloudservers.com/). You'll need the app's **App ID** and **App Secret** (Design > Core App Info).

## Configuring a sample

None of these samples ship with real credentials. Each one reads its connection info from a `bc_config.json` file that you create in the sample's root folder (it's gitignored, so your credentials won't be committed):

```json
{
    "serverUrl": "https://api.braincloudservers.com/dispatcherv2",
    "secretKey": "<app secret from brainCloud portal>",
    "appId": "<app id from brainCloud portal>",
    "version": "1.0.0"
}
```

Point every sample at its own brainCloud app — don't reuse one app across samples.

## Samples

| Sample | Description |
|---|---|
| [AceyDeucey](AceyDeucey/README.md) | Casino-style card betting game — bet on whether a drawn card falls between two others, with cloud code scripts settling the virtual currency. |
| [bc_chat](bc_chat/README.md) | Real-time chat demo built on brainCloud's Messaging service. |
| [spider_solitaire](spider_solitaire/README.md) | Spider Solitaire with anonymous auth, player stats, and a cloud code script for username claims. |

## Running a sample

```shell
cd <SampleName>
flutter pub get
flutter run --dart-define-from-file=bc_config.json
```

See each sample's README for anything specific to it (enabling Chat, uploading cloud code, etc).

---

For more on brainCloud, check out the [brainCloud Docs](https://getbraincloud.com/apidocs/) and the [Dart client repository](https://github.com/getbraincloud/braincloud-dart).
