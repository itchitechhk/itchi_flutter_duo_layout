import Flutter
import SwiftUI
import UIKit

/// Streams Duo fold pose to Flutter.
///
/// Poses:
/// - closed: hinge closed (cover)
/// - halfOpen: hinge partially open
/// - fullyOpen: hinge fully open and window spans both panes
/// - fullyOpenHalfScreen: hinge fully open but window is single-pane sized
final class ItchiFoldStreamHandler: NSObject, FlutterStreamHandler {
  private let resolveHost: () -> UIViewController?
  private var eventSink: FlutterEventSink?
  private var hostingController: UIHostingController<AnyView>?
  private weak var attachedView: UIView?
  private var lastPayload: NSDictionary?
  private var boundsObserver: NSObjectProtocol?
  private var sceneObservers: [NSObjectProtocol] = []
  private var attachTimer: Timer?
  private var lastHingeStatus: String?
  private var lastAngleDegrees: Double?

  init(resolveHost: @escaping () -> UIViewController?) {
    self.resolveHost = resolveHost
    super.init()
  }

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stop()
    eventSink = events
    guard #available(iOS 27.1, *) else {
      emitUnavailable("osUnavailable")
      return nil
    }
    startLifecycleWatch()
    tryAttach()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    return nil
  }

  deinit { stop() }

  private func startLifecycleWatch() {
    let center = NotificationCenter.default
    for name in [
      UIScene.didActivateNotification,
      UIApplication.didBecomeActiveNotification,
      UIDevice.orientationDidChangeNotification,
    ] {
      sceneObservers.append(center.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] _ in
        guard let self else { return }
        if #available(iOS 27.1, *) {
          self.tryAttach()
        }
      })
    }
    attachTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) {
      [weak self] _ in
      guard let self else { return }
      if #available(iOS 27.1, *) {
        self.tryAttach()
      }
    }
  }

  @available(iOS 27.1, *)
  private func tryAttach() {
    guard eventSink != nil else { return }
    guard let parent = resolveHost(),
          let view = parent.viewIfLoaded,
          let window = view.window else {
      detachHost()
      emitUnavailable("viewUnavailable")
      return
    }
    let active = window.windowScene.map { $0.activationState == .foregroundActive }
      ?? (UIApplication.shared.applicationState == .active)
    guard active else {
      detachHost()
      emitUnavailable("inactive")
      return
    }

    if attachedView === view, hostingController?.viewIfLoaded?.superview === view {
      // Still attached; recompute pose if window size changed.
      if let status = lastHingeStatus {
        emitPose(status: status, angleDegrees: lastAngleDegrees, in: view)
      }
      return
    }

    detachHost()
    emitUnavailable("waiting")

    let content = ItchiHingeObserverView { [weak self] status, angle in
      DispatchQueue.main.async {
        guard let self = self, let view = self.attachedView else { return }
        self.lastHingeStatus = status
        self.lastAngleDegrees = angle
        if status == nil {
          self.emitUnavailable("noHinge")
          return
        }
        self.emitPose(status: status!, angleDegrees: angle, in: view)
      }
    }

    let controller = UIHostingController(rootView: AnyView(content))
    hostingController = controller
    attachedView = view
    parent.addChild(controller)
    controller.view.backgroundColor = .clear
    controller.view.isUserInteractionEnabled = false
    controller.view.accessibilityElementsHidden = true
    controller.view.frame = view.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(controller.view)
    controller.didMove(toParent: parent)

    boundsObserver = NotificationCenter.default.addObserver(
      forName: UIDevice.orientationDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self = self, let view = self.attachedView,
            let status = self.lastHingeStatus else { return }
      self.emitPose(status: status, angleDegrees: self.lastAngleDegrees, in: view)
    }
  }

  private func emitPose(status: String, angleDegrees: Double?, in view: UIView) {
    let size = view.bounds.size
    let shortSide = min(size.width, size.height)
    let longSide = max(size.width, size.height)
    let spansBothPanes = shortSide >= 600 && longSide >= 640

    let pose: String
    switch status {
    case "closed":
      pose = "closed"
    case "partiallyOpen":
      pose = "halfOpen"
    case "fullyOpen":
      pose = spansBothPanes ? "fullyOpen" : "fullyOpenHalfScreen"
    default:
      pose = "unknown"
    }

    var payload: [String: Any] = [
      "version": 1,
      "availability": "available",
      "hingeStatus": status,
      "pose": pose,
      "windowWidth": size.width,
      "windowHeight": size.height,
      "spansBothPanes": spansBothPanes,
    ]
    if let angleDegrees {
      payload["angleDegrees"] = angleDegrees
    } else {
      payload["angleDegrees"] = NSNull()
    }
    emit(payload)
  }

  private func emitUnavailable(_ reason: String) {
    emit([
      "version": 1,
      "availability": reason,
      "hingeStatus": NSNull(),
      "pose": NSNull(),
      "angleDegrees": NSNull(),
      "windowWidth": NSNull(),
      "windowHeight": NSNull(),
      "spansBothPanes": NSNull(),
    ])
  }

  private func emit(_ payload: [String: Any]) {
    guard eventSink != nil else { return }
    let dictionary = NSDictionary(dictionary: payload)
    guard lastPayload == nil || !dictionary.isEqual(lastPayload) else { return }
    lastPayload = dictionary
    eventSink?(payload)
  }

  private func detachHost() {
    if let boundsObserver {
      NotificationCenter.default.removeObserver(boundsObserver)
      self.boundsObserver = nil
    }
    hostingController?.willMove(toParent: nil)
    hostingController?.viewIfLoaded?.removeFromSuperview()
    hostingController?.removeFromParent()
    hostingController = nil
    attachedView = nil
  }

  private func stop() {
    attachTimer?.invalidate()
    attachTimer = nil
    for observer in sceneObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    sceneObservers.removeAll()
    detachHost()
    eventSink = nil
    lastPayload = nil
    lastHingeStatus = nil
    lastAngleDegrees = nil
  }
}

@available(iOS 27.1, *)
private struct ItchiHingeObserverView: View {
  let onChange: (_ status: String?, _ angleDegrees: Double?) -> Void

  var body: some View {
    Color.clear
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onHingeChange { _, context in
        guard let hinge = context.hinge else {
          onChange(nil, nil)
          return
        }
        let status: String
        switch hinge.status {
        case .closed: status = "closed"
        case .partiallyOpen: status = "partiallyOpen"
        case .fullyOpen: status = "fullyOpen"
        default: status = "unknown"
        }
        onChange(status, hinge.angle.degrees)
      }
  }
}
