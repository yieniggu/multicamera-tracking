import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/utils/email_verification_link.dart';
import 'package:multicamera_tracking/features/auth/presentation/widgets/auth_localization.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({super.key});

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen>
    with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  Timer? _pollTimer;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AuthBloc>().add(
      const AuthEmailVerificationCheckRequested(silent: true),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(
        const AuthEmailVerificationCheckRequested(silent: true),
      );
    });
    _listenToDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    context.read<AuthBloc>().add(
      const AuthEmailVerificationCheckRequested(silent: true),
    );
  }

  Future<void> _listenToDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _onDeepLink(initialUri);
    } on MissingPluginException {
      return;
    } catch (_) {
      // Best effort only.
    }

    try {
      _linkSub = _appLinks.uriLinkStream.listen(_onDeepLink, onError: (_) {});
    } on MissingPluginException {
      // Best effort only.
    }
  }

  void _onDeepLink(Uri? uri) {
    if (!mounted || uri == null) return;
    if (!isEmailVerificationDeepLink(uri)) return;
    context.read<AuthBloc>().add(
      const AuthEmailVerificationCheckRequested(silent: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthEmailVerificationRequired &&
          current.feedbackMessageKey != null,
      listener: (context, state) {
        if (state is! AuthEmailVerificationRequired) return;
        final key = state.feedbackMessageKey;
        if (key == null) return;
        final message = key == 'auth.emailVerificationResent'
            ? l10n.authEmailVerificationResent
            : authErrorMessage(context, key);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        context.read<AuthBloc>().add(AuthEmailVerificationFeedbackCleared());
      },
      builder: (context, state) {
        final verificationState = state is AuthEmailVerificationRequired
            ? state
            : const AuthEmailVerificationRequired(email: '');
        final email = verificationState.email;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.authEmailVerificationTitle),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.authEmailVerificationDescription(email)),
                  const SizedBox(height: 24),
                  if (verificationState.isChecking)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('email_verification_resend_button'),
                    onPressed:
                        verificationState.isChecking ||
                            verificationState.isResending
                        ? null
                        : () {
                            context.read<AuthBloc>().add(
                              AuthEmailVerificationResendRequested(),
                            );
                          },
                    child: verificationState.isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.authEmailVerificationResendButton),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('email_verification_use_another_account'),
                    onPressed:
                        verificationState.isChecking ||
                            verificationState.isResending
                        ? null
                        : () {
                            context.read<AuthBloc>().add(AuthSignedOut());
                          },
                    child: Text(l10n.authEmailVerificationUseAnotherAccount),
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
