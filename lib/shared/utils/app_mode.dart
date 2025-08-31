import 'package:flutter/foundation.dart';

/// Single source of truth for “remote (cloud) vs local (guest)”
final ValueNotifier<bool> remoteEnabled = ValueNotifier<bool>(false);

/// Trial = local/guest mode (i.e. remote disabled)
bool isTrialLocalMode() => !remoteEnabled.value;

/// Optional convenience setters (use if you prefer calling functions)
void enterGuestMode() => remoteEnabled.value = false;
void enterSignedInMode() => remoteEnabled.value = true;
