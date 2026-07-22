// Basic Flutter widget test for GourmetGo app.

import 'package:flutter_test/flutter_test.dart';

import 'package:gourmet_go/main.dart';

void main() {
  testWidgets('App smoke test - launches without errors',
      (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const GourmetGoApp());

    // Verify the app renders something (MaterialApp is present).
    expect(find.byType(GourmetGoApp), findsOneWidget);
  });
}
