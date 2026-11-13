import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:itchi_flutter_duo_layout/itchi_flutter_duo_layout.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('side rail setItems returns a status', (tester) async {
    final status = await ItchiDuoRail.setItems([ItchiRailItem.back()]);
    expect(
      status,
      anyOf(
        ItchiRailStatus.available,
        ItchiRailStatus.unsupportedPlatform,
        ItchiRailStatus.viewUnavailable,
        ItchiRailStatus.unknown,
      ),
    );
    await ItchiDuoRail.setItems(const []);
  });
}
