import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/auth_localization.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/social_auth_buttons.dart';

class RegisterScreen extends StatefulWidget {
  final bool enableGuestMigration;
  final bool showAlreadyHaveAccountAction;

  const RegisterScreen({
    super.key,
    this.enableGuestMigration = false,
    this.showAlreadyHaveAccountAction = true,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _shouldMigrateGuestData => widget.enableGuestMigration;

  @override
  void initState() {
    super.initState();
    debugPrint("[REGISTER-SCREEN] Init register screen state");
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthRegisteredWithEmail(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        shouldMigrateGuestData: _shouldMigrateGuestData,
      ),
    );
  }

  void _registerWithGoogle() {
    context.read<AuthBloc>().add(
      AuthSignedInWithGoogle(shouldMigrateGuestData: _shouldMigrateGuestData),
    );
  }

  void _registerWithMicrosoft() {
    context.read<AuthBloc>().add(
      AuthSignedInWithMicrosoft(
        shouldMigrateGuestData: _shouldMigrateGuestData,
      ),
    );
  }

  Future<void> _showLinkRequiredDialog(AuthLinkRequired state) async {
    final l10n = AppLocalizations.of(context)!;
    final providers = state.pendingLink.existingProviders.isEmpty
        ? [AuthProviderType.password]
        : state.pendingLink.existingProviders;
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
                      AuthPendingLinkResolvedWithProvider(
                        AuthProviderType.password,
                        shouldMigrateGuestData: _shouldMigrateGuestData,
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
                    AuthPendingLinkResolvedWithProvider(
                      provider,
                      shouldMigrateGuestData: _shouldMigrateGuestData,
                    ),
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

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (blocContext, state) async {
        if (state is AuthAuthenticated) {
          // Close Register and Login, reveal the existing AuthGate underneath.
          if (!mounted) return;
          Navigator.of(this.context).popUntil((route) => route.isFirst);
        } else if (state is AuthLinkRequired) {
          _showLinkRequiredDialog(state);
        } else if (state is AuthFailure) {
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(authErrorMessage(this.context, state.message)),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (!widget.showAlreadyHaveAccountAction)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('register_close_button'),
                        icon: const Icon(Icons.close),
                        tooltip: l10n.authDismiss,
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.authCreateAccountTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('register_email_field'),
                          controller: emailCtrl,
                          enabled: !isLoading,
                          decoration: InputDecoration(
                            labelText: l10n.authEmailLabel,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.validationEmailRequired;
                            }
                            if (!value.contains('@')) {
                              return l10n.validationInvalidEmail;
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          key: const Key('register_password_field'),
                          controller: passCtrl,
                          enabled: !isLoading,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.authPasswordLabel,
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return l10n.validationPasswordMinLength;
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          key: const Key('register_confirm_password_field'),
                          controller: confirmCtrl,
                          enabled: !isLoading,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.authConfirmPasswordLabel,
                          ),
                          validator: (value) {
                            if (value != passCtrl.text) {
                              return l10n.validationPasswordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          key: const Key('register_submit_button'),
                          onPressed: isLoading ? null : _submitRegistration,
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.authCreateAccountButton),
                        ),
                        const SizedBox(height: 12),
                        SocialAuthButtons(
                          isLoading: isLoading,
                          onGooglePressed: _registerWithGoogle,
                          onMicrosoftPressed: _registerWithMicrosoft,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.showAlreadyHaveAccountAction)
                    TextButton(
                      key: const Key('open_login_button'),
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.authAlreadyHaveAccount),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
