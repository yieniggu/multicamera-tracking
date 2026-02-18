import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/shared/presentation/screen/initial_home_shell_screen.dart';

void main() {
  testWidgets('initial shell renders with projects tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InitialHomeShellScreen(
          isGuest: true,
          projectsTabBuilder: (_) => const Center(child: Text('Projects Home')),
          discoveryTabBuilder: (_) =>
              const Center(child: Text('Discovery Home')),
        ),
      ),
    );

    expect(find.text('Projects Home'), findsOneWidget);
    expect(find.text('Discovery Home'), findsNothing);
  });
}
