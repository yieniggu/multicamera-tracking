import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/send_password_reset_email.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/auth_localization.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final SendPasswordResetEmailUseCase? sendPasswordResetEmailUseCase;

  const ForgotPasswordScreen({super.key, this.sendPasswordResetEmailUseCase});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _submittedEmail;
  String? _errorMessageKey;

  SendPasswordResetEmailUseCase get _sendPasswordResetEmailUseCase =>
      widget.sendPasswordResetEmailUseCase ??
      getIt<SendPasswordResetEmailUseCase>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessageKey = null;
      _submittedEmail = null;
    });

    try {
      await _sendPasswordResetEmailUseCase(email);
      if (!mounted) return;
      setState(() => _submittedEmail = email);
    } on AuthFailureException catch (e) {
      if (!mounted) return;
      if (e.code == AuthFailureCode.invalidCredentials) {
        setState(() => _submittedEmail = email);
      } else {
        setState(() => _errorMessageKey = _messageFor(e));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessageKey = 'auth.error.generic');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  String _messageFor(AuthFailureException e) {
    switch (e.code) {
      case AuthFailureCode.network:
        return 'auth.error.network';
      case AuthFailureCode.cancelled:
        return 'auth.error.cancelled';
      case AuthFailureCode.unknown:
      case AuthFailureCode.invalidCredentials:
      case AuthFailureCode.emailNotVerified:
      case AuthFailureCode.emailAlreadyInUse:
      case AuthFailureCode.accountAlreadyExists:
      case AuthFailureCode.accountExistsWithDifferentCredential:
      case AuthFailureCode.credentialAlreadyInUse:
      case AuthFailureCode.requiresRecentLogin:
      case AuthFailureCode.pendingCredentialNotFound:
        return 'auth.error.generic';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.authForgotPasswordDescription),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('forgot_password_email_field'),
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.authEmailLabel),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return l10n.validationEmailRequired;
                    if (!email.contains('@'))
                      return l10n.validationInvalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('forgot_password_submit_button'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.authForgotPasswordSubmit),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('forgot_password_back_button'),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: Text(l10n.authForgotPasswordBackToLogin),
                ),
                if (_submittedEmail != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('forgot_password_confirmation_text'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.authForgotPasswordConfirmation(_submittedEmail!),
                    ),
                  ),
                ],
                if (_errorMessageKey != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authErrorMessage(context, _errorMessageKey!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
