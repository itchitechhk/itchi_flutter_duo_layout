import 'package:flutter_test/flutter_test.dart';
import 'package:itchi_flutter_duo_layout_example/main.dart';

void main() {
  testWidgets('example app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('itchi_flutter_duo_layout'), findsOneWidget);
    expect(find.text('Show side Back'), findsOneWidget);
  });
}
