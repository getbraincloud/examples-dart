import Cocoa
import FlutterMacOS
import GameKit

/// macOS counterpart of ios/Runner/GameCenterAuthPlugin.swift.
final class GameCenterAuthPlugin {
  static let channelName = "spider_solitaire/game_center"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(Self.hasGameCenterEntitlement())
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
    "Not signed in to Game Center. Sign in from System Settings > Game Center, then try again."

  // Game Center is opt-in on macOS (see macos/Flutter/Local.xcconfig.example).
  private static func hasGameCenterEntitlement() -> Bool {
    guard let task = SecTaskCreateFromSelf(nil) else { return false }
    let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.game-center" as CFString, nil)
    return (value as? Bool) == true
  }

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
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      if pending != nil && !localPlayer.isAuthenticated {
        fail("GC_TIMEOUT", "Game Center didn't respond. Sign out and back in from System Settings > Game Center, then try again.")
      }
    }
    localPlayer.authenticateHandler = { viewController, error in
      NSLog("GameCenterAuthPlugin: authenticateHandler vc=\(viewController != nil) error=\(String(describing: error)) authenticated=\(localPlayer.isAuthenticated)")
      if let viewController {
        DispatchQueue.main.async {
          guard let presenter = NSApp.keyWindow?.contentViewController
            ?? NSApp.mainWindow?.contentViewController
            ?? NSApp.windows.first?.contentViewController
          else {
            fail("GC_NO_PRESENTER", "No window to present Game Center sign-in.")
            return
          }
          presenter.presentAsSheet(viewController)
        }
        return
      }
      if let error {
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
        "gameCenterId": GKLocalPlayer.local.teamPlayerID,
        "publicKeyUrl": publicKeyUrl.absoluteString,
        "timestamp": Int(timestamp),
        "signature": FlutterStandardTypedData(bytes: signature),
        "salt": FlutterStandardTypedData(bytes: salt),
      ])
    }
  }
}
