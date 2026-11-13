import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itchi_flutter_duo_layout/itchi_flutter_duo_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('itchi_flutter_duo_layout/side_back');
  final log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return {'status': 'available'};
    });
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setVisible invokes setItems with default back', () async {
    final status = await ItchiDuoSideBack.setVisible(true);
    expect(status, ItchiSideBackStatus.available);
    expect(log.single.method, 'setItems');
    final args = log.single.arguments as Map;
    final items = args['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['id'], ItchiRailItem.backId);
    expect((items.first as Map)['systemImage'], 'chevron.left');
  });

  test('setItems sends custom text and trailing buttons', () async {
    final status = await ItchiDuoRail.setItems([
      ItchiRailItem.backText(title: 'Close'),
      const ItchiRailItem(
        id: 'done',
        title: 'Done',
        placement: ItchiRailPlacement.trailing,
        priority: ItchiRailPriority.high,
      ),
    ]);
    expect(status, ItchiRailStatus.available);
    expect(log.single.method, 'setItems');
    final items = (log.single.arguments as Map)['items'] as List;
    expect(items, hasLength(2));
    expect((items[0] as Map)['title'], 'Close');
    expect((items[1] as Map)['id'], 'done');
    expect((items[1] as Map)['placement'], 'trailing');
  });

  test('DuoFoldSnapshot parses fullyOpen', () {
    final snap = DuoFoldSnapshot.fromMessage({
      'version': 1,
      'availability': 'available',
      'hingeStatus': 'fullyOpen',
      'pose': 'fullyOpen',
      'angleDegrees': 180.0,
      'windowWidth': 951.0,
      'windowHeight': 669.0,
      'spansBothPanes': true,
    });
    expect(snap.isAvailable, isTrue);
    expect(snap.pose, DuoFoldPose.fullyOpen);
    expect(snap.wantsTwoPanes, isTrue);
    expect(snap.angleDegrees, 180.0);
  });

  test('DuoFoldSnapshot parses fullyOpenHalfScreen', () {
    final snap = DuoFoldSnapshot.fromMessage({
      'version': 1,
      'availability': 'available',
      'hingeStatus': 'fullyOpen',
      'pose': 'fullyOpenHalfScreen',
      'angleDegrees': 180.0,
      'windowWidth': 466.0,
      'windowHeight': 678.0,
      'spansBothPanes': false,
    });
    expect(snap.pose, DuoFoldPose.fullyOpenHalfScreen);
    expect(snap.wantsTwoPanes, isFalse);
  });

  test('DuoFoldSnapshot unavailable', () {
    final snap = DuoFoldSnapshot.fromMessage({
      'version': 1,
      'availability': 'osUnavailable',
      'hingeStatus': null,
      'pose': null,
      'angleDegrees': null,
      'windowWidth': null,
      'windowHeight': null,
      'spansBothPanes': null,
    });
    expect(snap.isAvailable, isFalse);
    expect(snap.availability, DuoFoldAvailability.osUnavailable);
    expect(snap.pose, isNull);
  });
}
