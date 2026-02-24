import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/account_profile_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/account_settings_screen.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';

class PreferencesScreen extends StatelessWidget {
  final bool isGuest;

  const PreferencesScreen({super.key, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.preferencesTitle)),
      body: ListView(
        children: [
          if (!isGuest)
            ListTile(
              key: const Key('preferences_account_profile_tile'),
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.accountProfileTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountProfileScreen(),
                  ),
                );
              },
            ),
          if (!isGuest)
            ListTile(
              key: const Key('preferences_account_security_tile'),
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.accountSecurityTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
              },
            ),
          ListTile(
            key: const Key('preferences_logout_tile'),
            leading: const Icon(Icons.logout),
            title: Text(l10n.accountSettingsLogout),
            onTap: () {
              context.read<AuthBloc>().add(AuthSignedOut());
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
