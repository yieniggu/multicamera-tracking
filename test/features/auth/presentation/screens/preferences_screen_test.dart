import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/preferences_screen.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool isGuest}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PreferencesScreen(isGuest: isGuest),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders profile/security/logout tiles for non-guest', (
    tester,
  ) async {
    await pump(tester, isGuest: false);

    expect(
      find.byKey(const Key('preferences_account_profile_tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('preferences_account_security_tile')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('preferences_logout_tile')), findsOneWidget);
  });

  testWidgets('hides profile/security tiles and keeps logout for guest', (
    tester,
  ) async {
    await pump(tester, isGuest: true);

    expect(
      find.byKey(const Key('preferences_account_profile_tile')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('preferences_account_security_tile')),
      findsNothing,
    );
    expect(find.byKey(const Key('preferences_logout_tile')), findsOneWidget);
  });
}
