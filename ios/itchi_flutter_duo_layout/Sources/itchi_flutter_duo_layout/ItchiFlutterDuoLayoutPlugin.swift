import Flutter
import UIKit

/// Applies Flutter-configured items into Duo's system vertical side rail
/// via UINavigationItem leading/trailing groups.
public class ItchiFlutterDuoLayoutPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var foldHandler: ItchiFoldStreamHandler?
  private weak var wrappedFlutter: FlutterViewController?
  private weak var navigation: UINavigationController?
  private var currentItems: [[String: Any]] = []

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "itchi_flutter_duo_layout/side_back",
      binaryMessenger: registrar.messenger()
    )
    let instance = ItchiFlutterDuoLayoutPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)

    let foldChannel = FlutterEventChannel(
      name: "itchi_flutter_duo_layout/fold",
      binaryMessenger: registrar.messenger()
    )
    let foldHandler = ItchiFoldStreamHandler { [weak instance] in
      instance?.resolveFlutterController()
    }
    instance.foldHandler = foldHandler
    foldChannel.setStreamHandler(foldHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setItems":
      guard let args = call.arguments as? [String: Any],
            let rawItems = args["items"] as? [[String: Any]] else {
        result(FlutterError(code: "invalid_arguments", message: "items required", details: nil))
        return
      }
      result(setItems(rawItems))
    case "setVisible":
      // Legacy: show/hide default chevron back.
      guard let args = call.arguments as? [String: Any],
            let visible = args["visible"] as? Bool else {
        result(FlutterError(code: "invalid_arguments", message: "visible required", details: nil))
        return
      }
      if visible {
        result(setItems([[
          "id": "back",
          "systemImage": "chevron.left",
          "placement": "leading",
          "priority": "high",
          "enabled": true,
          "visible": true,
          "accessibilityLabel": "Back",
        ]]))
      } else {
        result(setItems([]))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setItems(_ items: [[String: Any]]) -> [String: Any] {
    currentItems = items
    guard let flutter = resolveFlutterController() else {
      return ["status": "viewUnavailable"]
    }

    let trailing = flutter.viewIfLoaded?.safeAreaInsets.right
      ?? flutter.view?.safeAreaInsets.right
      ?? 0

    let visibleItems = items.filter { ($0["visible"] as? Bool) ?? true }

    if trailing < 48 {
      clearRailItems(on: flutter)
      return [
        "status": visibleItems.isEmpty ? "available" : "unsupportedPlatform",
        "trailing": trailing,
      ]
    }

    guard ensureNavigationWrapper(for: flutter) else {
      return ["status": "viewUnavailable", "trailing": trailing]
    }

    applyRailItems(visibleItems, on: flutter)
    return [
      "status": "available",
      "trailing": trailing,
      "mode": "sideRail",
      "count": visibleItems.count,
    ]
  }

  @discardableResult
  private func ensureNavigationWrapper(for flutter: FlutterViewController) -> Bool {
    if let existing = flutter.navigationController {
      navigation = existing
      wrappedFlutter = flutter
      existing.isNavigationBarHidden = false
      existing.interactivePopGestureRecognizer?.isEnabled = false
      return true
    }

    guard let window = flutter.viewIfLoaded?.window ?? flutter.view?.window else {
      return false
    }

    if window.rootViewController === flutter {
      window.rootViewController = nil
      let nav = UINavigationController(rootViewController: flutter)
      configureNavigation(nav)
      window.rootViewController = nav
      navigation = nav
      wrappedFlutter = flutter
      return true
    }

    if let parent = flutter.parent {
      flutter.willMove(toParent: nil)
      flutter.removeFromParent()
      let nav = UINavigationController(rootViewController: flutter)
      configureNavigation(nav)
      parent.addChild(nav)
      if let container = parent.viewIfLoaded {
        nav.view.frame = container.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(nav.view)
      }
      nav.didMove(toParent: parent)
      navigation = nav
      wrappedFlutter = flutter
      return true
    }

    return false
  }

  private func configureNavigation(_ nav: UINavigationController) {
    nav.isNavigationBarHidden = false
    nav.interactivePopGestureRecognizer?.isEnabled = false
    nav.navigationBar.prefersLargeTitles = false
  }

  private func applyRailItems(_ items: [[String: Any]], on flutter: FlutterViewController) {
    guard #available(iOS 16.0, *) else { return }

    flutter.navigationItem.largeTitleDisplayMode = .never
    flutter.navigationItem.leftItemsSupplementBackButton = false

    let leadingConfigs = items.filter { ($0["placement"] as? String) != "trailing" }
    let trailingConfigs = items.filter { ($0["placement"] as? String) == "trailing" }

    let leading = leadingConfigs.map { makeBarButton(from: $0) }
    let trailing = trailingConfigs.map { makeBarButton(from: $0) }

    flutter.navigationItem.leadingItemGroups = leading.isEmpty ? [] : [
      UIBarButtonItemGroup(barButtonItems: leading, representativeItem: nil),
    ]
    flutter.navigationItem.trailingItemGroups = trailing.isEmpty ? [] : [
      UIBarButtonItemGroup(barButtonItems: trailing, representativeItem: nil),
    ]
    flutter.navigationController?.isNavigationBarHidden = false
  }

  private func clearRailItems(on flutter: FlutterViewController?) {
    guard #available(iOS 16.0, *), let flutter else { return }
    flutter.navigationItem.leadingItemGroups = []
    flutter.navigationItem.trailingItemGroups = []
  }

  private func makeBarButton(from config: [String: Any]) -> UIBarButtonItem {
    let id = (config["id"] as? String) ?? UUID().uuidString
    let title = config["title"] as? String
    let systemImage = config["systemImage"] as? String
    let enabled = (config["enabled"] as? Bool) ?? true
    let accessibility = (config["accessibilityLabel"] as? String) ?? title ?? id
    let image = systemImage.flatMap { UIImage(systemName: $0) }
    let hasTitle = !(title ?? "").isEmpty

    let item = UIBarButtonItem(
      title: hasTitle ? title : nil,
      image: image,
      primaryAction: UIAction { [weak self] _ in
        self?.channel.invokeMethod("onItemTap", arguments: ["id": id])
        if id == "back" {
          self?.channel.invokeMethod("onBack", arguments: nil)
        }
      },
      menu: nil
    )
    item.isEnabled = enabled
    item.accessibilityLabel = accessibility

    if #available(iOS 27.1, *) {
      switch config["priority"] as? String {
      case "high": item.visibilityPriority = .high
      case "low": item.visibilityPriority = .low
      default: break
      }
      item.axisBehavior = .verticalPreferred
    }
    return item
  }

  private func resolveFlutterController() -> FlutterViewController? {
    if let wrappedFlutter, wrappedFlutter.viewIfLoaded?.window != nil {
      return wrappedFlutter
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      for window in scene.windows {
        if let controller = findFlutterController(in: window.rootViewController) {
          return controller
        }
      }
    }
    return nil
  }

  private func findFlutterController(in controller: UIViewController?) -> FlutterViewController? {
    guard let controller else { return nil }
    if let flutter = controller as? FlutterViewController {
      return flutter
    }
    if let nav = controller as? UINavigationController {
      if let flutter = nav.viewControllers.compactMap({ $0 as? FlutterViewController }).first {
        return flutter
      }
    }
    for child in controller.children {
      if let found = findFlutterController(in: child) { return found }
    }
    return findFlutterController(in: controller.presentedViewController)
  }
}
