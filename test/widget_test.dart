import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/main.dart';

void main() {
  testWidgets('App renders ConnectScreen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FieldFlashApp()));
    // ConnectScreen shows the USB icon or waiting indicator
    expect(find.byIcon(Icons.usb), findsOneWidget);
  });
}
