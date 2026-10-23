import Flutter
import GameKit
import UIKit

/// Bridges Apple Game Center identity verification to Dart. brainCloud's
/// `authenticateGameCenter` needs the local player's id plus an identity
/// verification signature (timestamp/publicKeyUrl/signature/salt) fetched
/// from GameKit, none of which Flutter can reach without a platform
/// channel — see `GameCenterAuthService` on the Dart side.
final class GameCenterAuthPlugin {
  static let channelName = "spider_solitaire/game_center"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "signIn":
        Self.signIn(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static var pending: FlutterResult?
  private static var handlerInstalled = false
  private static let notSignedInMessage =
    "Not signed in to Game Center. Sign in from Settings > Game Center, then try again."

  private static func respond(_ value: Any?) {
    DispatchQueue.main.async {
      guard let result = pending else { return }
      pending = nil
      result(value)
    }
  }

  private static func fail(_ code: String, _ message: String) {
    NSLog("GameCenterAuthPlugin: \(code) \(message)")
    respond(FlutterError(code: code, message: message, details: nil))
  }

  private static func signIn(result: @escaping FlutterResult) {
    if pending != nil {
      result(FlutterError(code: "GC_BUSY", message: "Game Center sign-in already in progress.", details: nil))
      return
    }
    pending = result
    let localPlayer = GKLocalPlayer.local
    NSLog("GameCenterAuthPlugin: signIn (authenticated=\(localPlayer.isAuthenticated), handlerInstalled=\(handlerInstalled))")

    if localPlayer.isAuthenticated {
      fetchSignature()
      return
    }
    // GameKit calls authenticateHandler once per launch, so a second tap gets no callback.
    if handlerInstalled {
      fail("GC_NOT_AUTHENTICATED", notSignedInMessage)
      return
    }
    handlerInstalled = true
    // gamed can stall without ever calling back (seen after a simulator reboot).
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      if pending != nil && !localPlayer.isAuthenticated {
        fail("GC_TIMEOUT", "Game Center didn't respond. Sign out and back in from Settings > Game Center, then try again.")
      }
    }
    localPlayer.authenticateHandler = { viewController, error in
      NSLog("GameCenterAuthPlugin: authenticateHandler vc=\(viewController != nil) error=\(String(describing: error)) authenticated=\(localPlayer.isAuthenticated)")
      if let viewController {
        DispatchQueue.main.async {
          guard let presenter = topViewController() else {
            fail("GC_NO_PRESENTER", "No view controller to present Game Center sign-in.")
            return
          }
          presenter.present(viewController, animated: true)
        }
        return
      }
      if let error {
        // iOS returns these without showing UI when the player isn't signed in or dismissed the prompt.
        let code = (error as NSError).code
        if code == GKError.notAuthenticated.rawValue || code == GKError.cancelled.rawValue {
          fail("GC_NOT_AUTHENTICATED", notSignedInMessage)
        } else {
          fail("GC_AUTH_FAILED", error.localizedDescription)
        }
        return
      }
      guard localPlayer.isAuthenticated else {
        fail("GC_NOT_AUTHENTICATED", "Game Center authentication was not completed.")
        return
      }
      // GameKit also calls back when the player signs in from Settings later.
      DispatchQueue.main.async {
        if pending != nil { fetchSignature() }
      }
    }
  }

  private static func fetchSignature() {
    GKLocalPlayer.local.fetchItems { publicKeyUrl, signature, salt, timestamp, error in
      if let error {
        fail("GC_SIGNATURE_FAILED", error.localizedDescription)
        return
      }
      guard let publicKeyUrl, let signature, let salt else {
        fail("GC_SIGNATURE_FAILED", "Game Center did not return identity verification data.")
        return
      }
      NSLog("GameCenterAuthPlugin: signature fetched")
      respond([
        // The signature covers teamPlayerID, so using it as the id needs no separate teamPlayerId.
        "gameCenterId": GKLocalPlayer.local.teamPlayerID,
        "publicKeyUrl": publicKeyUrl.absoluteString,
        "timestamp": Int(timestamp),
        "signature": FlutterStandardTypedData(bytes: signature),
        "salt": FlutterStandardTypedData(bytes: salt),
      ])
    }
  }

  // Falls back to any foreground window; scene-based apps may have no key window yet.
  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
