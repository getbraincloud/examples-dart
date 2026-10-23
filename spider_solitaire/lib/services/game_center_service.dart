import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GameCenterAuthException implements Exception {
  GameCenterAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A signed Game Center identity, as fetched from `GKLocalPlayer` on the
/// native side. Passed straight through to
/// `BrainCloudService.authenticateGameCenter`, which forwards it to
/// brainCloud for server-side verification against Apple.
class GameCenterSignature {
  GameCenterSignature({
    required this.gameCenterId,
    required this.publicKeyUrl,
    required this.timestamp,
    required this.signature,
    required this.salt,
  });

  final String gameCenterId;
  final String publicKeyUrl;
  final int timestamp;
  final List<int> signature;
  final List<int> salt;
}

/// Talks to the native `GameCenterAuthPlugin` (see
/// `ios/Runner/GameCenterAuthPlugin.swift`) over a method channel to sign
/// in to Game Center and fetch an identity verification signature.
///
/// Game Center is Apple-only — [isAvailable] gates every call so callers
/// can hide the option elsewhere instead of hitting a missing channel.
class GameCenterAuthService {
  static const _channel = MethodChannel('spider_solitaire/game_center');

  // dart:io's Platform throws on web.
  static Future<bool>? _available;

  /// iOS always; macOS only when built with the Game Center entitlement
  /// (opt-in via macos/Flutter/Local.xcconfig).
  Future<bool> isAvailable() => _available ??= _checkAvailable();

  Future<bool> _checkAvailable() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) return true;
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Signs in to Game Center (presenting Apple's UI if needed) and fetches
  /// an identity verification signature for the local player.
  ///
  /// Throws [GameCenterAuthException] if unsupported, cancelled by the
  /// user, or GameKit fails to produce a signature.
  Future<GameCenterSignature> signIn() async {
    if (!await isAvailable()) {
      throw GameCenterAuthException('Game Center is not available on this platform.');
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, Object?>('signIn');
      if (result == null) {
        throw GameCenterAuthException(
          'Game Center sign-in returned no data.',
        );
      }
      return GameCenterSignature(
        gameCenterId: result['gameCenterId'] as String,
        publicKeyUrl: result['publicKeyUrl'] as String,
        timestamp: result['timestamp'] as int,
        signature: result['signature'] as Uint8List,
        salt: result['salt'] as Uint8List,
      );
    } on PlatformException catch (e) {
      throw GameCenterAuthException(
        e.message ?? 'Game Center sign-in failed.',
      );
    }
  }
}
