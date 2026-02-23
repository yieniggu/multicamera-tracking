import 'package:flutter/foundation.dart';

@immutable
class DependencyConfig {
  final bool useFirebaseEmulators;
  final String authEmulatorHost;
  final int authEmulatorPort;
  final String firestoreEmulatorHost;
  final int firestoreEmulatorPort;
  final String hiveBoxSuffix;

  const DependencyConfig({
    this.useFirebaseEmulators = false,
    this.authEmulatorHost = '127.0.0.1',
    this.authEmulatorPort = 9099,
    this.firestoreEmulatorHost = '127.0.0.1',
    this.firestoreEmulatorPort = 8080,
    this.hiveBoxSuffix = '',
  });

  const DependencyConfig.emulators({
    this.authEmulatorHost = '127.0.0.1',
    this.authEmulatorPort = 9099,
    this.firestoreEmulatorHost = '127.0.0.1',
    this.firestoreEmulatorPort = 8080,
    this.hiveBoxSuffix = '',
  }) : useFirebaseEmulators = true;

  factory DependencyConfig.fromEnvironment() {
    return DependencyConfig(
      useFirebaseEmulators: const bool.fromEnvironment(
        'USE_FIREBASE_EMULATORS',
        defaultValue: false,
      ),
      authEmulatorHost: const String.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      authEmulatorPort: int.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      ),
      firestoreEmulatorHost: const String.fromEnvironment(
        'FIRESTORE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      firestoreEmulatorPort: int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      ),
      hiveBoxSuffix: const String.fromEnvironment(
        'HIVE_BOX_SUFFIX',
        defaultValue: '',
      ),
    );
  }

  String boxName(String base) {
    if (hiveBoxSuffix.trim().isEmpty) return base;
    return '${base}_$hiveBoxSuffix';
  }
}
