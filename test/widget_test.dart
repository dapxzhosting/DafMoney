import 'package:flutter_test/flutter_test.dart';
import 'package:daf_money/app.dart';

void main() {
  testWidgets('DafMoney app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DafMoneyApp());
    expect(find.text('DafMoney'), findsOneWidget);
  });
}
