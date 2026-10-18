import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devtrack_desktop/main.dart';

void main() {
  testWidgets('DevTrackApp launches and displays LoginScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DevTrackApp());
    expect(find.text('DevTrack'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
