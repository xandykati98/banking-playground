import 'package:flutter_test/flutter_test.dart';

import 'package:banking_playground/main.dart';

void main() {
  testWidgets('App renders prompt bar smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BankingPlaygroundApp());

    expect(find.text('Banking Playground'), findsOneWidget);
  });
}
