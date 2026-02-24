import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/presentation/utils/email_verification_link.dart';

void main() {
  test('detects direct verify-email action links', () {
    final uri = Uri.parse(
      'https://project.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=ABC123',
    );

    expect(isEmailVerificationDeepLink(uri), isTrue);
  });

  test('detects nested verify-email action links', () {
    final uri = Uri.parse(
      'myapp://auth?link=https%3A%2F%2Fproject.firebaseapp.com%2F__%2Fauth%2Faction%3Fmode%3DverifyEmail%26oobCode%3DABC123',
    );

    expect(isEmailVerificationDeepLink(uri), isTrue);
  });

  test('ignores non-verification links', () {
    final uri = Uri.parse(
      'https://project.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=ABC123',
    );

    expect(isEmailVerificationDeepLink(uri), isFalse);
  });
}
