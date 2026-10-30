import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_app/main.dart';

void main() {
  testWidgets('Wasel app launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const WaselApp());
    await tester.pumpAndSettle();

    expect(find.text('Wasel'), findsWidgets);
  });
}
