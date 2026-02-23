import 'package:flutter/material.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialAuthButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onGooglePressed;
  final VoidCallback onMicrosoftPressed;

  const SocialAuthButtons({
    super.key,
    required this.isLoading,
    required this.onGooglePressed,
    required this.onMicrosoftPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authOrContinueWith,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('google_sign_in_button'),
          onPressed: isLoading ? null : onGooglePressed,
          icon: const FaIcon(FontAwesomeIcons.google, size: 16),
          label: Text(l10n.authSignInWithGoogle),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('microsoft_sign_in_button'),
          onPressed: isLoading ? null : onMicrosoftPressed,
          icon: const FaIcon(FontAwesomeIcons.microsoft, size: 16),
          label: Text(l10n.authSignInWithMicrosoft),
        ),
      ],
    );
  }
}
