import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_state.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/shared/presentation/bloc/app_locale_cubit.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _didInitialSync = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountProfileBloc>(
      create: (_) =>
          getIt<AccountProfileBloc>()..add(const AccountProfileRequested()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<AppLocaleCubit, AppLocaleState>(
            listenWhen: (previous, current) =>
                previous.errorMessageKey != current.errorMessageKey &&
                current.errorMessageKey != null,
            listener: (context, localeState) {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.preferencesLanguageSaveError)),
              );
            },
          ),
        ],
        child: BlocConsumer<AccountProfileBloc, AccountProfileState>(
          listener: (context, state) {
            if (!_didInitialSync && !state.isLoading) {
              _syncControllers(state);
              _didInitialSync = true;
            }

            if (state.lastSuccessMessageKey == 'profile.success.saved') {
              _syncControllers(state);
            }

            final l10n = AppLocalizations.of(context)!;
            if (state.lastErrorMessageKey != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_messageFor(l10n, state.lastErrorMessageKey!)),
                ),
              );
              context.read<AccountProfileBloc>().add(
                const AccountProfileFeedbackCleared(),
              );
            }
            if (state.lastSuccessMessageKey != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _messageFor(l10n, state.lastSuccessMessageKey!),
                  ),
                ),
              );
              context.read<AccountProfileBloc>().add(
                const AccountProfileFeedbackCleared(),
              );
            }
          },
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;
            final localeState = context.watch<AppLocaleCubit>().state;

            return Scaffold(
              appBar: AppBar(title: Text(l10n.accountProfileTitle)),
              body: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            title: Text(l10n.accountProfileEmailLabel),
                            subtitle: Text(
                              state.email.isEmpty
                                  ? l10n.accountSettingsNoEmail
                                  : state.email,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('account_profile_language_dropdown'),
                          value: localeState.locale.languageCode,
                          decoration: InputDecoration(
                            labelText: l10n.accountProfileLanguageLabel,
                            suffixIcon: localeState.isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'es',
                              child: Text(
                                '🇪🇸 ${l10n.preferencesLanguageSpanish}',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(
                                '🇬🇧 ${l10n.preferencesLanguageEnglish}',
                              ),
                            ),
                          ],
                          onChanged: localeState.isSaving || state.isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  context.read<AppLocaleCubit>().setLanguage(
                                    value,
                                  );
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_profile_first_name_field'),
                          controller: _firstNameController,
                          enabled: !state.isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.accountProfileFirstNameLabel,
                            errorText: state.firstName.trim().isEmpty
                                ? l10n.accountProfileFirstNameRequired
                                : null,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            context.read<AccountProfileBloc>().add(
                              AccountProfileFirstNameChanged(value),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_profile_last_name_field'),
                          controller: _lastNameController,
                          enabled: !state.isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.accountProfileLastNameLabel,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            context.read<AccountProfileBloc>().add(
                              AccountProfileLastNameChanged(value),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_profile_phone_field'),
                          controller: _phoneController,
                          enabled: !state.isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.accountProfilePhoneLabel,
                            hintText: '+34123456789',
                            errorText: state.isPhoneValid
                                ? null
                                : l10n.accountProfilePhoneInvalid,
                          ),
                          keyboardType: TextInputType.phone,
                          onChanged: (value) {
                            context.read<AccountProfileBloc>().add(
                              AccountProfilePhoneChanged(value),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('account_profile_save_button'),
                          onPressed: state.canSave
                              ? () {
                                  context.read<AccountProfileBloc>().add(
                                    const AccountProfileSaveSubmitted(),
                                  );
                                }
                              : null,
                          child: state.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.accountProfileSave),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  void _syncControllers(AccountProfileState state) {
    _firstNameController.text = state.firstName;
    _lastNameController.text = state.lastName;
    _phoneController.text = state.phoneNumber;
  }

  String _messageFor(AppLocalizations l10n, String key) {
    switch (key) {
      case 'profile.success.saved':
        return l10n.accountProfileSaveSuccess;
      case 'profile.error.firstNameRequired':
        return l10n.accountProfileFirstNameRequired;
      case 'profile.error.phoneInvalid':
        return l10n.accountProfilePhoneInvalid;
      case 'profile.error.load':
        return l10n.accountProfileLoadError;
      case 'profile.error.save':
      default:
        return l10n.accountProfileSaveError;
    }
  }
}
