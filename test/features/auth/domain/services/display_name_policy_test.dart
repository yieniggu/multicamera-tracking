import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/domain/services/display_name_policy.dart';

void main() {
  group('resolveDisplayName', () {
    test('prefers email local-part when email exists', () {
      final result = resolveDisplayName(
        email: 'camera.admin@example.com',
        providerDisplayName: 'Provider Name',
      );

      expect(result, 'camera.admin');
    });

    test('falls back to provider display name when email missing', () {
      final result = resolveDisplayName(
        email: null,
        providerDisplayName: 'Microsoft User',
      );

      expect(result, 'Microsoft User');
    });

    test('falls back to generic user when no email and no provider name', () {
      final result = resolveDisplayName(email: null, providerDisplayName: null);

      expect(result, 'User');
    });
  });
}
