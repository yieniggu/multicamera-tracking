import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/pending_auth_link.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/send_password_reset_email.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastPasswordResetEmail;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  PendingAuthLink? get pendingAuthLink => null;

  @override
  void clearPendingAuthLink() {}

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async => false;

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastPasswordResetEmail = email;
  }

  @override
  Future<AuthUser?> signInAnonymously() async => null;

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      null;

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser?> signInWithMicrosoft({String? emailHint}) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<List<AuthProviderType>> getLinkedSignInMethods() async => const [];

  @override
  Future<String?> getContactEmail() async => null;

  @override
  Future<void> setPassword(String newPassword) async {}

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> changeEmail(String newEmail) async {}

  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> reauthenticateWithMicrosoft() async {}

  @override
  Future<String?> getPendingEmailVerificationEmail() async => null;

  @override
  Future<String?> refreshPendingEmailVerificationEmail() async => null;

  @override
  Future<void> sendEmailVerificationToCurrentUser() async {}
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    SendPasswordResetEmailUseCase useCase,
  ) async {
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
        home: ForgotPasswordScreen(sendPasswordResetEmailUseCase: useCase),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('submits and shows generic confirmation message', (tester) async {
    final repository = _FakeAuthRepository();
    await pumpScreen(tester, SendPasswordResetEmailUseCase(repository));

    await tester.enterText(
      find.byKey(const Key('forgot_password_email_field')),
      'owner@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
    await tester.pumpAndSettle();

    expect(repository.lastPasswordResetEmail, 'owner@example.com');
    expect(
      find.byKey(const Key('forgot_password_confirmation_text')),
      findsOneWidget,
    );
    expect(find.textContaining('owner@example.com'), findsWidgets);
  });
}
