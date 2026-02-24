import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_settings_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_settings_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_settings_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/auth_localization.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _setPasswordController = TextEditingController();
  final _setPasswordConfirmController = TextEditingController();
  final _changePasswordController = TextEditingController();
  final _changePasswordConfirmController = TextEditingController();
  final _changeEmailController = TextEditingController();

  @override
  void dispose() {
    _setPasswordController.dispose();
    _setPasswordConfirmController.dispose();
    _changePasswordController.dispose();
    _changePasswordConfirmController.dispose();
    _changeEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountSettingsBloc>(
      create: (_) =>
          getIt<AccountSettingsBloc>()..add(const AccountSettingsRequested()),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is AuthUnauthenticated && mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        child: BlocConsumer<AccountSettingsBloc, AccountSettingsState>(
          listener: (context, state) {
            if (state.lastErrorMessageKey != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    authErrorMessage(context, state.lastErrorMessageKey!),
                  ),
                ),
              );
              context.read<AccountSettingsBloc>().add(
                const AccountSettingsFeedbackCleared(),
              );
            }
            if (state.lastSuccessMessageKey != null) {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _successMessage(l10n, state.lastSuccessMessageKey!),
                  ),
                ),
              );
              context.read<AccountSettingsBloc>().add(
                const AccountSettingsFeedbackCleared(),
              );
            }
          },
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;

            return Scaffold(
              appBar: AppBar(title: Text(l10n.accountSettingsTitle)),
              body: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildContactEmailCard(l10n, state),
                        const SizedBox(height: 12),
                        _buildLinkedMethodsCard(l10n, state),
                        const SizedBox(height: 12),
                        if (!state.hasPasswordMethod)
                          _buildSetPasswordCard(context, l10n, state)
                        else
                          _buildChangePasswordCard(context, l10n, state),
                        const SizedBox(height: 12),
                        _buildChangeEmailCard(context, l10n, state),
                        if (state.requiresReauth) ...[
                          const SizedBox(height: 12),
                          _buildReauthCard(context, l10n, state),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactEmailCard(
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      child: ListTile(
        title: Text(l10n.accountSettingsContactEmail),
        subtitle: Text(state.contactEmail ?? l10n.accountSettingsNoEmail),
      ),
    );
  }

  Widget _buildLinkedMethodsCard(
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSettingsLinkedMethods,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('account_linked_methods_wrap'),
              spacing: 8,
              runSpacing: 8,
              children: state.linkedMethods.map((provider) {
                return Chip(label: Text(_providerLabel(l10n, provider)));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetPasswordCard(
    BuildContext blocContext,
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSettingsSetPassword,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account_set_password_field'),
              controller: _setPasswordController,
              enabled: !state.isAnyActionInFlight,
              decoration: InputDecoration(labelText: l10n.authPasswordLabel),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('account_set_password_confirm_field'),
              controller: _setPasswordConfirmController,
              enabled: !state.isAnyActionInFlight,
              decoration: InputDecoration(
                labelText: l10n.authConfirmPasswordLabel,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('account_set_password_button'),
              onPressed: state.isAnyActionInFlight
                  ? null
                  : () {
                      final password = _setPasswordController.text.trim();
                      final confirm = _setPasswordConfirmController.text.trim();
                      if (!_isValidPassword(password, confirm, blocContext)) {
                        return;
                      }
                      blocContext.read<AccountSettingsBloc>().add(
                        AccountSettingsSetPasswordSubmitted(password),
                      );
                    },
              child: state.isSetPasswordInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.accountSettingsSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(
    BuildContext blocContext,
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSettingsChangePassword,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account_change_password_field'),
              controller: _changePasswordController,
              enabled: !state.isAnyActionInFlight,
              decoration: InputDecoration(labelText: l10n.authPasswordLabel),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('account_change_password_confirm_field'),
              controller: _changePasswordConfirmController,
              enabled: !state.isAnyActionInFlight,
              decoration: InputDecoration(
                labelText: l10n.authConfirmPasswordLabel,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('account_change_password_button'),
              onPressed: state.isAnyActionInFlight
                  ? null
                  : () {
                      final password = _changePasswordController.text.trim();
                      final confirm = _changePasswordConfirmController.text
                          .trim();
                      if (!_isValidPassword(password, confirm, blocContext)) {
                        return;
                      }
                      blocContext.read<AccountSettingsBloc>().add(
                        AccountSettingsChangePasswordSubmitted(password),
                      );
                    },
              child: state.isChangePasswordInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.accountSettingsSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeEmailCard(
    BuildContext blocContext,
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSettingsChangeEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account_change_email_field'),
              controller: _changeEmailController,
              enabled: !state.isAnyActionInFlight,
              decoration: InputDecoration(labelText: l10n.authEmailLabel),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('account_change_email_button'),
              onPressed: state.isAnyActionInFlight
                  ? null
                  : () {
                      final email = _changeEmailController.text.trim();
                      if (!_isValidEmail(email, blocContext)) return;
                      blocContext.read<AccountSettingsBloc>().add(
                        AccountSettingsChangeEmailSubmitted(email),
                      );
                    },
              child: state.isChangeEmailInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.accountSettingsSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReauthCard(
    BuildContext blocContext,
    AppLocalizations l10n,
    AccountSettingsState state,
  ) {
    return Card(
      key: const Key('account_reauth_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSettingsReauthTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(l10n.accountSettingsReauthDescription),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.linkedMethods.contains(AuthProviderType.password))
                  OutlinedButton(
                    key: const Key('account_reauth_password_button'),
                    onPressed: state.isReauthInFlight
                        ? null
                        : () => _showPasswordReauthDialog(blocContext, state),
                    child: Text(l10n.authUsePasswordToContinue),
                  ),
                if (state.linkedMethods.contains(AuthProviderType.google))
                  OutlinedButton(
                    key: const Key('account_reauth_google_button'),
                    onPressed: state.isReauthInFlight
                        ? null
                        : () {
                            blocContext.read<AccountSettingsBloc>().add(
                              const AccountSettingsReauthenticateWithGoogleRequested(),
                            );
                          },
                    child: Text(l10n.authSignInWithGoogle),
                  ),
                if (state.linkedMethods.contains(AuthProviderType.microsoft))
                  OutlinedButton(
                    key: const Key('account_reauth_microsoft_button'),
                    onPressed: state.isReauthInFlight
                        ? null
                        : () {
                            blocContext.read<AccountSettingsBloc>().add(
                              const AccountSettingsReauthenticateWithMicrosoftRequested(),
                            );
                          },
                    child: Text(l10n.authSignInWithMicrosoft),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordReauthDialog(
    BuildContext blocContext,
    AccountSettingsState state,
  ) async {
    final context = blocContext;
    final bloc = blocContext.read<AccountSettingsBloc>();
    final email = state.contactEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.authErrorGeneric)),
      );
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.accountSettingsReauthTitle),
          content: TextField(
            key: const Key('account_reauth_password_field'),
            controller: controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.authPasswordLabel,
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppLocalizations.of(context)!.authDismiss),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppLocalizations.of(context)!.accountSettingsSave),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      controller.dispose();
      return;
    }
    bloc.add(
      AccountSettingsReauthenticateWithPasswordSubmitted(
        email: email,
        password: controller.text,
      ),
    );
    controller.dispose();
  }

  bool _isValidPassword(String password, String confirm, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (password.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.validationPasswordMinLength)));
      return false;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.validationPasswordsDoNotMatch)),
      );
      return false;
    }
    return true;
  }

  bool _isValidEmail(String email, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.validationEmailRequired)));
      return false;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.validationInvalidEmail)));
      return false;
    }
    return true;
  }

  String _providerLabel(AppLocalizations l10n, AuthProviderType provider) {
    switch (provider) {
      case AuthProviderType.password:
        return l10n.authEmailLabel;
      case AuthProviderType.google:
        return l10n.accountSettingsMethodGoogle;
      case AuthProviderType.microsoft:
        return l10n.accountSettingsMethodMicrosoft;
      case AuthProviderType.unknown:
        return 'Unknown';
    }
  }

  String _successMessage(AppLocalizations l10n, String key) {
    switch (key) {
      case 'account.success.passwordSet':
        return l10n.accountSettingsPasswordSetSuccess;
      case 'account.success.passwordChanged':
        return l10n.accountSettingsPasswordChangedSuccess;
      case 'account.success.emailChanged':
        return l10n.accountSettingsEmailChangedSuccess;
      default:
        return l10n.authErrorGeneric;
    }
  }
}
