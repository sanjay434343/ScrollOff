// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scrolloff/main.dart';

void main() {
  testWidgets('ScrollOff app launches and focus mode toggles', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScrollOffApp());

    // Verify that our app shows the correct initial state.
    expect(find.text('ScrollOff'), findsOneWidget);
    expect(find.text('Focus Mode Inactive'), findsOneWidget);
    expect(find.text('Start Focus'), findsOneWidget);

    // Tap the 'Start Focus' button and trigger a frame.
    await tester.tap(find.text('Start Focus'));
    await tester.pump();

    // Verify that focus mode has been activated.
    expect(find.text('Focus Mode Active'), findsOneWidget);
    expect(find.text('Stop Focus'), findsOneWidget);
    expect(find.text('Distracting apps will be blocked'), findsOneWidget);
  });

  testWidgets('Navigation to settings works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScrollOffApp());

    // Tap the settings icon in the app bar.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify that we navigated to the settings page.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Focus Schedule'), findsOneWidget);
  });

  testWidgets('Navigation to apps list works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScrollOffApp());

    // Tap the 'Manage Blocked Apps' button.
    await tester.tap(find.text('Manage Blocked Apps'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the apps list page.
    expect(find.text('Blocked Apps'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
  });
}
