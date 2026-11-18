// Basic Flutter widget smoke test for the RYDO customer app.

import 'package:flutter_test/flutter_test.dart';

import 'package:rydo_customer/main.dart';

void main() {
  testWidgets('RydoApp builds without crashing', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const RydoApp());

    // The splash screen shows the app name "RYDO".
    expect(find.text('RYDO'), findsOneWidget);
  });
}
