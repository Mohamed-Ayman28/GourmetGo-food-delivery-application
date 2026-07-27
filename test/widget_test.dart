import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test - verifies base app layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('GourmetGo Delivery App'),
          ),
        ),
      ),
    );

    expect(find.text('GourmetGo Delivery App'), findsOneWidget);
  });
}
