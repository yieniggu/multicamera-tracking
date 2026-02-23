# Firebase Emulator E2E

## Start emulators

```bash
firebase emulators:start --only auth,firestore
```

## Run integration tests

### iOS simulator / macOS

```bash
./.fvm/flutter_sdk/bin/flutter test integration_test/app_emulator_e2e_test.dart \
  --dart-define=RUN_FIREBASE_EMULATOR_E2E=true \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1 \
  --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1
```

### Android emulator

```bash
./.fvm/flutter_sdk/bin/flutter test integration_test/app_emulator_e2e_test.dart \
  --dart-define=RUN_FIREBASE_EMULATOR_E2E=true \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_AUTH_EMULATOR_HOST=10.0.2.2 \
  --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2
```

## Notes

- Tests are skipped unless `RUN_FIREBASE_EMULATOR_E2E=true`.
- DI automatically connects to emulators when `USE_FIREBASE_EMULATORS=true`.
- The suite wipes Auth + Firestore emulator data between tests.
