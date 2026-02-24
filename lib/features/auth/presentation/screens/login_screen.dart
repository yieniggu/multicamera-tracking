import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/register_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/auth_localization.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/social_auth_buttons.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/reset_local_debug_data.dart';

class LoginScreen extends StatefulWidget {
  final bool enableGuestMigration;

  const LoginScreen({super.key, this.enableGuestMigration = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool hideGuestButton = false;
  bool _linkDialogInFlight = false;
  String? _lastShownFailureKey;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyGuest();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('is_guest') ?? false;
    if (!mounted) return;
    setState(() => hideGuestButton = isGuest);
  }

  void _loginWithEmail() {
    context.read<AuthBloc>().add(
      AuthSignedInWithEmail(emailCtrl.text.trim(), passCtrl.text.trim()),
    );
  }

  void _loginAsGuest() {
    context.read<AuthBloc>().add(AuthSignedInAnonymously());
  }

  void _loginWithGoogle() {
    context.read<AuthBloc>().add(const AuthSignedInWithGoogle());
  }

  void _loginWithMicrosoft() {
    context.read<AuthBloc>().add(const AuthSignedInWithMicrosoft());
  }

  Future<void> _resetLocalDataDebug() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = l10n.authDebugResetLocalDataSuccess;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.authDebugResetLocalDataTitle),
          content: Text(l10n.authDebugResetLocalDataDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.authDismiss),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.authDebugResetLocalDataConfirm),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    await getIt<ResetLocalDebugDataUseCase>()();
    if (!mounted) return;
    await _checkIfAlreadyGuest();
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _showLinkRequiredDialog(AuthLinkRequired state) async {
    final l10n = AppLocalizations.of(context)!;
    final providers = state.pendingLink.existingProviders;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.authLinkRequiredTitle),
          content: Text(
            l10n.authLinkRequiredDescription(
              state.pendingLink.email.isEmpty
                  ? emailCtrl.text.trim()
                  : state.pendingLink.email,
              authProviderLabel(context, state.pendingLink.pendingProvider),
            ),
          ),
          actions: [
            ...providers.map((provider) {
              if (provider == AuthProviderType.password) {
                return TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.read<AuthBloc>().add(
                      const AuthPendingLinkResolvedWithProvider(
                        AuthProviderType.password,
                      ),
                    );
                  },
                  child: Text(l10n.authUsePasswordToContinue),
                );
              }
              return TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.read<AuthBloc>().add(
                    AuthPendingLinkResolvedWithProvider(provider),
                  );
                },
                child: Text(
                  l10n.authContinueWithProvider(
                    authProviderLabel(context, provider),
                  ),
                ),
              );
            }),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(AuthPendingLinkCleared());
              },
              child: Text(l10n.authDismiss),
            ),
          ],
        );
      },
    );
  }

  void _showFailureSnackbar(String messageKey) {
    if (!mounted) return;
    if (_lastShownFailureKey == messageKey) return;
    _lastShownFailureKey = messageKey;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(authErrorMessage(context, messageKey))),
    );
  }

  void _ensureLinkRequiredDialog(AuthLinkRequired state) {
    if (_linkDialogInFlight) return;
    _linkDialogInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _linkDialogInFlight = false;
        return;
      }
      try {
        await _showLinkRequiredDialog(state);
      } finally {
        _linkDialogInFlight = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (blocContext, state) async {
        if (state is AuthAuthenticated) {
          if (!mounted) return;
          final navigator = Navigator.of(this.context);
          if (state.requiresMigrationConfirmation) {
            navigator.popUntil((route) => route.isFirst);
            return;
          }
          // AuthGate (underneath) will now rebuild to HomeScreen.
          // We just close the Login route if it's on top.
          if (navigator.canPop()) {
            navigator.pop();
          }
        } else if (state is AuthEmailVerificationRequired) {
          if (!mounted) return;
          final navigator = Navigator.of(this.context);
          if (navigator.canPop()) {
            navigator.popUntil((route) => route.isFirst);
          }
        } else if (state is AuthLinkRequired) {
          _ensureLinkRequiredDialog(state);
        } else if (state is AuthFailure) {
          _showFailureSnackbar(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        if (state is AuthFailure) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFailureSnackbar(state.message);
          });
        } else {
          _lastShownFailureKey = null;
        }
        if (state is AuthLinkRequired) {
          _ensureLinkRequiredDialog(state);
        }
        return Scaffold(
          appBar: AppBar(title: Text(l10n.authLoginTitle)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  key: const Key('login_email_field'),
                  controller: emailCtrl,
                  enabled: !isLoading,
                  decoration: InputDecoration(labelText: l10n.authEmailLabel),
                ),
                TextField(
                  key: const Key('login_password_field'),
                  controller: passCtrl,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: l10n.authPasswordLabel,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('email_sign_in_button'),
                  onPressed: isLoading ? null : _loginWithEmail,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.authLoginButton),
                ),
                TextButton(
                  key: const Key('forgot_password_button'),
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  child: Text(l10n.authForgotPasswordAction),
                ),
                const SizedBox(height: 12),
                SocialAuthButtons(
                  isLoading: isLoading,
                  onGooglePressed: _loginWithGoogle,
                  onMicrosoftPressed: _loginWithMicrosoft,
                ),
                TextButton(
                  key: const Key('open_register_button'),
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(
                                enableGuestMigration:
                                    widget.enableGuestMigration,
                              ),
                            ),
                          );
                        },
                  child: Text(l10n.authNoAccountRegister),
                ),
                if (!hideGuestButton)
                  TextButton.icon(
                    key: const Key('guest_sign_in_button'),
                    icon: const Icon(Icons.person_outline),
                    label: Text(l10n.authEnterAsGuest),
                    onPressed: isLoading ? null : _loginAsGuest,
                  ),
                if (kDebugMode && state is! AuthAuthenticated)
                  TextButton(
                    key: const Key('debug_reset_local_data_button'),
                    onPressed: isLoading ? null : _resetLocalDataDebug,
                    child: Text(l10n.authDebugResetLocalDataAction),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
