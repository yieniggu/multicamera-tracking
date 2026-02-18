import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/shared/presentation/screen/initial_home_shell_screen.dart';

void main() {
  testWidgets('shows Projects by default and switches tabs from bottom bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InitialHomeShellScreen(
          isGuest: false,
          projectsTabBuilder: (_) => const Center(child: Text('Projects Tab')),
          discoveryTabBuilder: (_) =>
              const Center(child: Text('Discovery Tab')),
        ),
      ),
    );

    expect(find.text('Projects Tab'), findsOneWidget);
    expect(find.text('Discovery Tab'), findsNothing);

    await tester.tap(find.text('Discovery'));
    await tester.pumpAndSettle();

    expect(find.text('Discovery Tab'), findsOneWidget);
    expect(find.text('Projects Tab'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Projects Tab'), findsOneWidget);
    expect(find.text('Discovery Tab'), findsNothing);
  });
}
