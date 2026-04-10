import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:vibegrowth_sdk_example/main.dart';

void main() {
  testWidgets('renders server URL controls before SDK initialization',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Vibe Growth Example'), findsWidgets);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Initialize SDK'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(InputDecorator, 'Base URL'), findsOneWidget);
    expect(find.text('SDK Not Initialized'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Automation Activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Automation Activity'), findsOneWidget);
    expect(find.text('No automation commands received yet.'), findsOneWidget);
  });
}
