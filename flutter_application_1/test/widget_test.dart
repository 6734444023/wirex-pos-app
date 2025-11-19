// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Login page renders expected UI', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Username'), findsWidgets);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('เลือกภาษา'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
