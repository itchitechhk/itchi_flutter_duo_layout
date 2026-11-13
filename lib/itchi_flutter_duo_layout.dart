import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status returned when applying native side-rail items.
enum ItchiRailStatus {
  available,
  unsupportedPlatform,
  viewUnavailable,
  unknown,
}

/// Where an item sits in Duo's vertical system rail.
enum ItchiRailPlacement { leading, trailing }

/// Overflow / keep priority when the rail is crowded.
enum ItchiRailPriority { automatic, low, high }

/// One native side-rail control (icon, text, or both).
@immutable
class ItchiRailItem {
  const ItchiRailItem({
    required this.id,
    this.title,
    this.systemImage,
    this.placement = ItchiRailPlacement.leading,
    this.priority = ItchiRailPriority.automatic,
    this.enabled = true,
    this.visible = true,
    this.accessibilityLabel,
  }) : assert(
          title != null || systemImage != null,
          'ItchiRailItem needs a title and/or systemImage.',
        );

  /// Default Back chevron used by [ItchiDuoSideBack] / app chrome.
  static const String backId = 'back';

  /// Icon-only back (SF Symbol `chevron.left`).
  factory ItchiRailItem.back({
    String id = backId,
    String systemImage = 'chevron.left',
    String accessibilityLabel = 'Back',
    ItchiRailPriority priority = ItchiRailPriority.high,
  }) =>
      ItchiRailItem(
        id: id,
        systemImage: systemImage,
        accessibilityLabel: accessibilityLabel,
        priority: priority,
      );

  /// Text back / Close style control (optional icon).
  factory ItchiRailItem.backText({
    String id = backId,
    String title = 'Back',
    String? systemImage,
    String? accessibilityLabel,
    ItchiRailPriority priority = ItchiRailPriority.high,
  }) =>
      ItchiRailItem(
        id: id,
        title: title,
        systemImage: systemImage,
        accessibilityLabel: accessibilityLabel ?? title,
        priority: priority,
      );

  final String id;
  final String? title;

  /// SF Symbol name, e.g. `chevron.left`, `xmark`.
  final String? systemImage;
  final ItchiRailPlacement placement;
  final ItchiRailPriority priority;
  final bool enabled;
  final bool visible;
  final String? accessibilityLabel;

  Map<String, Object?> toMessage() => {
        'id': id,
        'title': title,
        'systemImage': systemImage,
        'placement': placement.name,
        'priority': priority.name,
        'enabled': enabled,
        'visible': visible,
        'accessibilityLabel': accessibilityLabel,
      };
}

/// Generic Duo side-rail API (system vertical bar via UINavigationItem).
class ItchiDuoRail {
  ItchiDuoRail._();

  static const MethodChannel _channel =
      MethodChannel('itchi_flutter_duo_layout/side_back');

  static StreamController<String>? _tapController;
  static bool _handlerAttached = false;

  /// Emits the tapped item [ItchiRailItem.id].
  static Stream<String> get onItemTap {
    _ensureHandler();
    return _tapController!.stream;
  }

  static void _ensureHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;
    _tapController = StreamController<String>.broadcast();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onItemTap') {
        final id = call.arguments is Map
            ? call.arguments['id']?.toString()
            : call.arguments?.toString();
        if (id != null && id.isNotEmpty) {
          _tapController?.add(id);
        }
      } else if (call.method == 'onBack') {
        // Legacy native callback — treat as default back.
        _tapController?.add(ItchiRailItem.backId);
      }
    });
  }

  /// Replace all native side-rail items. Pass `[]` to clear.
  static Future<ItchiRailStatus> setItems(List<ItchiRailItem> items) async {
    _ensureHandler();
    try {
      final result = await _channel.invokeMethod<Object?>('setItems', {
        'items': items.map((e) => e.toMessage()).toList(growable: false),
      });
      return _statusFrom(result);
    } on MissingPluginException {
      return ItchiRailStatus.unsupportedPlatform;
    } on PlatformException {
      return ItchiRailStatus.viewUnavailable;
    }
  }

  static ItchiRailStatus _statusFrom(Object? result) {
    if (result is! Map) return ItchiRailStatus.unknown;
    final name = result['status']?.toString();
    return ItchiRailStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => ItchiRailStatus.unknown,
    );
  }
}

/// Convenience wrapper around [ItchiDuoRail] for the default Back control.
class ItchiDuoSideBack {
  ItchiDuoSideBack._();

  /// Emits when the default back item (`[ItchiRailItem.backId]`) is tapped.
  static Stream<void> get onBack => ItchiDuoRail.onItemTap
      .where((id) => id == ItchiRailItem.backId)
      .map((_) {});

  /// Show or hide the default chevron Back in the side rail.
  static Future<ItchiSideBackStatus> setVisible(bool visible) async {
    final status = await ItchiDuoRail.setItems(
      visible ? [ItchiRailItem.back()] : const <ItchiRailItem>[],
    );
    switch (status) {
      case ItchiRailStatus.available:
        return ItchiSideBackStatus.available;
      case ItchiRailStatus.unsupportedPlatform:
        return ItchiSideBackStatus.unsupportedPlatform;
      case ItchiRailStatus.viewUnavailable:
        return ItchiSideBackStatus.viewUnavailable;
      case ItchiRailStatus.unknown:
        return ItchiSideBackStatus.unknown;
    }
  }
}

/// Status returned by [ItchiDuoSideBack.setVisible].
enum ItchiSideBackStatus {
  available,
  unsupportedPlatform,
  viewUnavailable,
  unknown,
}

/// Whether a live fold measurement is available.
enum DuoFoldAvailability {
  available,
  waiting,
  noHinge,
  inactive,
  viewUnavailable,
  osUnavailable,
  unsupportedPlatform,
}

/// Device fold / hinge pose for layout switching.
enum DuoFoldPose {
  /// Device closed (cover screen).
  closed,

  /// Hinge partially open (tent / laptop-like).
  halfOpen,

  /// Fully open and window spans both panes.
  fullyOpen,

  /// Fully open, but app window is half-screen / single pane.
  fullyOpenHalfScreen,

  /// Forward-compatible unknown hinge status.
  unknown,
}

/// Raw hinge status from the OS (before window-size pose mapping).
enum DuoHingeStatus { closed, partiallyOpen, fullyOpen, unknown }

@immutable
class DuoFoldSnapshot {
  const DuoFoldSnapshot._({
    required this.availability,
    this.pose,
    this.hingeStatus,
    this.angleDegrees,
    this.windowWidth,
    this.windowHeight,
    this.spansBothPanes,
  });

  factory DuoFoldSnapshot.unavailable(DuoFoldAvailability availability) {
    if (availability == DuoFoldAvailability.available) {
      throw ArgumentError('Available fold needs a pose.');
    }
    return DuoFoldSnapshot._(availability: availability);
  }

  final DuoFoldAvailability availability;
  final DuoFoldPose? pose;
  final DuoHingeStatus? hingeStatus;
  final double? angleDegrees;
  final double? windowWidth;
  final double? windowHeight;
  final bool? spansBothPanes;

  bool get isAvailable => availability == DuoFoldAvailability.available;

  /// Dual-pane content layout (only when fully open spanning both panes).
  bool get wantsTwoPanes => pose == DuoFoldPose.fullyOpen;

  factory DuoFoldSnapshot.fromMessage(Object? message) {
    if (message is! Map || message['version'] != 1) {
      throw const FormatException('Unsupported fold message.');
    }
    final availabilityName = message['availability']?.toString();
    final availability = DuoFoldAvailability.values.firstWhere(
      (v) => v.name == availabilityName,
      orElse: () => DuoFoldAvailability.unsupportedPlatform,
    );
    if (availability != DuoFoldAvailability.available) {
      return DuoFoldSnapshot.unavailable(availability);
    }

    final poseName = message['pose']?.toString();
    final pose = DuoFoldPose.values.firstWhere(
      (v) => v.name == poseName,
      orElse: () => DuoFoldPose.unknown,
    );
    final hingeName = message['hingeStatus']?.toString();
    final hinge = DuoHingeStatus.values.firstWhere(
      (v) => v.name == hingeName,
      orElse: () => DuoHingeStatus.unknown,
    );
    final angle = message['angleDegrees'];
    final w = message['windowWidth'];
    final h = message['windowHeight'];
    final spans = message['spansBothPanes'];

    return DuoFoldSnapshot._(
      availability: availability,
      pose: pose,
      hingeStatus: hinge,
      angleDegrees: angle is num && angle.isFinite ? angle.toDouble() : null,
      windowWidth: w is num && w.isFinite ? w.toDouble() : null,
      windowHeight: h is num && h.isFinite ? h.toDouble() : null,
      spansBothPanes: spans is bool ? spans : null,
    );
  }
}

/// Live Duo fold / hinge stream from the native plugin.
class ItchiDuoFold {
  ItchiDuoFold._();

  static const EventChannel _channel =
      EventChannel('itchi_flutter_duo_layout/fold');

  static StreamController<DuoFoldSnapshot>? _controller;
  static StreamSubscription<dynamic>? _subscription;

  /// Continuous fold pose updates. Falls back to unavailable on missing plugin.
  static Stream<DuoFoldSnapshot> get snapshots {
    _ensureListening();
    return _controller!.stream;
  }

  static void _ensureListening() {
    if (_controller != null) return;
    final controller = StreamController<DuoFoldSnapshot>.broadcast(
      onListen: () {},
      onCancel: () {
        if (!(_controller?.hasListener ?? true)) {
          _subscription?.cancel();
          _subscription = null;
        }
      },
    );
    _controller = controller;
    try {
      _subscription = _channel.receiveBroadcastStream().listen(
        (event) {
          try {
            controller.add(DuoFoldSnapshot.fromMessage(event));
          } on FormatException {
            controller.add(
              DuoFoldSnapshot.unavailable(
                DuoFoldAvailability.unsupportedPlatform,
              ),
            );
          }
        },
        onError: (Object error) {
          if (error is MissingPluginException) {
            controller.add(
              DuoFoldSnapshot.unavailable(
                DuoFoldAvailability.unsupportedPlatform,
              ),
            );
          } else {
            controller.add(
              DuoFoldSnapshot.unavailable(DuoFoldAvailability.viewUnavailable),
            );
          }
        },
      );
    } on MissingPluginException {
      controller.add(
        DuoFoldSnapshot.unavailable(DuoFoldAvailability.unsupportedPlatform),
      );
    }
  }
}
