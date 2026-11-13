# itchi_flutter_duo_layout

Standalone Flutter **iOS plugin** for iPhone Duo:

1. **Side rail** — put Back (or other controls) in Duo’s system vertical strip without reparenting the Flutter view (avoids Metal blank screens from wrapping Flutter in a `UINavigationController`).
2. **Fold stream** — live hinge / fold pose so your UI can switch single-pane vs dual-pane.

This repository is **self-contained**. It has no dependency on any host app, backend, or product codebase. Host apps consume it as a normal Flutter plugin (Git / path / pub).

**Platform:** iOS only for native behavior. Other platforms return `unsupportedPlatform` / unavailable fold snapshots — safe to call.

---

## Requirements

| Item | Notes |
|------|--------|
| Flutter | `>= 3.3.0` |
| Dart | `^3.13.7` |
| iOS | Side rail on Duo-capable builds; **fold stream needs iOS 27.1+** |
| Xcode | Prefer **Xcode 27.1+ / iOS 27.1 SDK** so open-mode fills the inner display |
| Device | Physical **iPhone Duo**, or **iPhone Duo** Simulator |

Enable **UIScene** lifecycle in your app’s `ios/Runner` (current Flutter iOS templates already do).

---

## Install

### From GitHub

```yaml
dependencies:
  itchi_flutter_duo_layout:
    git:
      url: https://github.com/itchitechhk/itchi_flutter_duo_layout.git
      ref: main   # or a tag, e.g. v0.1.0
```

### Local path

```yaml
dependencies:
  itchi_flutter_duo_layout:
    path: path/to/itchi_flutter_duo_layout
```

Then:

```bash
flutter pub get
cd ios && pod install && cd ..
```

```dart
import 'package:itchi_flutter_duo_layout/itchi_flutter_duo_layout.dart';
```

---

## Quick start

### 1. Side Back (simplest)

```dart
import 'dart:async';
import 'package:itchi_flutter_duo_layout/itchi_flutter_duo_layout.dart';

StreamSubscription<void>? _backSub;

Future<void> enableDuoBack(NavigatorState nav) async {
  final status = await ItchiDuoSideBack.setVisible(true);
  // available | unsupportedPlatform | viewUnavailable | unknown

  _backSub = ItchiDuoSideBack.onBack.listen((_) {
    if (nav.canPop()) nav.maybePop();
  });
}

Future<void> disableDuoBack() async {
  await _backSub?.cancel();
  await ItchiDuoSideBack.setVisible(false);
}
```

Hide Flutter’s own AppBar leading when the native rail is active, so users don’t see two Back buttons.

### 2. Custom side-rail items

```dart
await ItchiDuoRail.setItems([
  ItchiRailItem.back(), // SF Symbol chevron.left, id: 'back'
  const ItchiRailItem(
    id: 'settings',
    systemImage: 'gearshape',
    placement: ItchiRailPlacement.trailing,
    accessibilityLabel: 'Settings',
  ),
]);

ItchiDuoRail.onItemTap.listen((id) {
  switch (id) {
    case ItchiRailItem.backId:
      // pop
      break;
    case 'settings':
      // open settings
      break;
  }
});

await ItchiDuoRail.setItems(const []); // clear
```

| Field | Purpose |
|-------|---------|
| `id` | Returned by `onItemTap` |
| `title` / `systemImage` | Label and/or SF Symbol (at least one required) |
| `placement` | `leading` or `trailing` on the vertical rail |
| `priority` | `automatic` / `low` / `high` when crowded |
| `enabled` / `visible` | Interaction and visibility |

### 3. Fold / hinge stream

```dart
ItchiDuoFold.snapshots.listen((snap) {
  if (!snap.isAvailable) {
    // Fallback: MediaQuery size thresholds, etc.
    return;
  }
  switch (snap.pose) {
    case DuoFoldPose.closed:
    case DuoFoldPose.halfOpen:
    case DuoFoldPose.fullyOpenHalfScreen:
      // typically single pane
      break;
    case DuoFoldPose.fullyOpen:
      // snap.wantsTwoPanes == true
      break;
    case DuoFoldPose.unknown:
    case null:
      break;
  }
});
```

Typical pattern: hold the latest `DuoFoldSnapshot` near the root and combine with `MediaQuery.sizeOf` so layout still works on iPad / phones without a hinge.

---

## Suggested host-app integration

This package is only the **native bridge**. Dual-pane widgets stay in your app.

1. **Global `navigatorKey`** — native Back calls `maybePop()` on that navigator.
2. **Fold scope** — listen to `ItchiDuoFold.snapshots` near the root; rebuild when pose changes.
3. **Size fallback** — e.g. short side ≥ ~600pt as two-pane when fold is unavailable.
4. **Clear rail on dispose** — `ItchiDuoRail.setItems([])`.

```dart
bool wantsTwoPanes(DuoFoldSnapshot? fold, Size window) {
  if (fold != null && fold.isAvailable) {
    return fold.wantsTwoPanes &&
        math.min(window.width, window.height) >= 600;
  }
  final short = math.min(window.width, window.height);
  final long = math.max(window.width, window.height);
  return short >= 600 && long >= 640;
}
```

---

## Status values

### `ItchiRailStatus` / `ItchiSideBackStatus`

| Value | Meaning |
|-------|---------|
| `available` | Items applied on the native rail |
| `unsupportedPlatform` | Not iOS / plugin missing |
| `viewUnavailable` | Flutter view not ready — retry after first frame |
| `unknown` | Unexpected native payload |

### `DuoFoldAvailability`

| Value | Meaning |
|-------|---------|
| `available` | Live pose in the snapshot |
| `waiting` | Attaching to hinge APIs |
| `noHinge` | Device has no fold hardware |
| `inactive` / `viewUnavailable` | Scene or view not ready |
| `osUnavailable` | OS below fold API (needs 27.1+) |
| `unsupportedPlatform` | Non-iOS or missing plugin |

---

## Example

[`example/`](example/) is a minimal host that only depends on this plugin (`path: ../`). It demos side Back + fold status. Run:

```bash
cd example
flutter run -d "iPhone Duo"
```

---

## API surface

| API | Role |
|-----|------|
| `ItchiDuoSideBack` | Show/hide default Back; `onBack` stream |
| `ItchiDuoRail` | Set arbitrary rail items; `onItemTap` |
| `ItchiRailItem` | Item model (+ `.back()` / `.backText()`) |
| `ItchiDuoFold` | `snapshots` → `DuoFoldSnapshot` |
| `DuoFoldPose` / `DuoHingeStatus` | Pose enums |

Channels:

- Method: `itchi_flutter_duo_layout/side_back`
- Event: `itchi_flutter_duo_layout/fold`

---

## Out of scope

- No dual-pane widget kit — build list/detail UI in the host app.
- Does **not** wrap Flutter in a `UINavigationController` (by design).
- Android / web / desktop are not implemented.

---

## License

[MIT](LICENSE) — free to use, modify, and redistribute (commercial and non‑commercial), with attribution.
