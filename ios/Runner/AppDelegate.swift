import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SecureTokenStorage"
    ) else {
      NSLog("SecureTokenStorage registrar is unavailable")
      return
    }
    let channel = FlutterMethodChannel(
      name: "church_app/secure_storage",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      SecureTokenStorage.handle(call: call, result: result)
    }
  }
}

private enum SecureTokenStorage {
  private static let service = Bundle.main.bundleIdentifier ?? "kr.churchapp.church-app"

  static func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "read":
      guard let key = arguments?["key"] as? String else {
        result(FlutterError(code: "invalid_arguments", message: "Missing key", details: nil))
        return
      }
      result(read(key: key))
    case "write":
      guard
        let key = arguments?["key"] as? String,
        let value = arguments?["value"] as? String
      else {
        result(FlutterError(code: "invalid_arguments", message: "Missing key/value", details: nil))
        return
      }
      do {
        try write(key: key, value: value)
        result(nil)
      } catch {
        result(FlutterError(code: "keychain_write", message: error.localizedDescription, details: nil))
      }
    case "deleteAll":
      let status = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
      if status == errSecSuccess || status == errSecItemNotFound {
        result(nil)
      } else {
        result(FlutterError(code: "keychain_delete", message: "Keychain status: \(status)", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func read(key: String) -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func write(key: String, value: String) throws {
    let base: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
    ]
    let data = Data(value.utf8)
    let updateStatus = SecItemUpdate(base as CFDictionary, [kSecValueData: data] as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
    }
    var create = base
    create[kSecValueData] = data
    create[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let createStatus = SecItemAdd(create as CFDictionary, nil)
    guard createStatus == errSecSuccess else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(createStatus))
    }
  }
}
