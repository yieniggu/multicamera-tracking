import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class AppLocaleCubit extends Cubit<AppLocaleState> {
  static const _languageKey = 'app_language';
  static const _allowedLanguages = {'es', 'en'};

  final UserProfileRepository userProfileRepository;
  final AuthRepository authRepository;
  final Locale Function() deviceLocaleProvider;

  bool _isHydrating = false;

  AppLocaleCubit({
    required this.userProfileRepository,
    required this.authRepository,
    Locale Function()? deviceLocaleProvider,
  }) : deviceLocaleProvider =
           deviceLocaleProvider ?? (() => PlatformDispatcher.instance.locale),
       super(const AppLocaleState(locale: Locale('es')));

  Future<void> hydrate() async {
    if (_isHydrating) return;
    _isHydrating = true;

    emit(state.copyWith(isHydrating: true, isSaving: false, clearError: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final localLanguage = _normalizeLanguage(prefs.getString(_languageKey));
      final deviceLanguage = _normalizeLanguage(
        deviceLocaleProvider().languageCode,
      );

      String? remoteLanguage;
      final currentUser = authRepository.currentUser;
      final isAuthenticated = currentUser != null && !currentUser.isAnonymous;

      if (isAuthenticated) {
        try {
          remoteLanguage = await userProfileRepository.getCurrentUserLanguage();
        } catch (_) {
          remoteLanguage = null;
        }
      }

      final resolvedLanguage =
          _normalizeLanguage(remoteLanguage) ??
          localLanguage ??
          deviceLanguage ??
          'es';

      await prefs.setString(_languageKey, resolvedLanguage);

      emit(
        state.copyWith(
          locale: Locale(resolvedLanguage),
          isHydrating: false,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(isHydrating: false, isSaving: false, clearError: true),
      );
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = _normalizeLanguage(languageCode);
    if (normalized == null || state.isSaving) return;

    emit(
      state.copyWith(
        locale: Locale(normalized),
        isSaving: true,
        isHydrating: false,
        clearError: true,
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, normalized);

      final currentUser = authRepository.currentUser;
      final isAuthenticated = currentUser != null && !currentUser.isAnonymous;

      if (isAuthenticated) {
        await userProfileRepository.updateCurrentUserLanguage(normalized);
      }

      emit(state.copyWith(isSaving: false, clearError: true));
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessageKey: 'preferences.languageSaveError',
        ),
      );
    }
  }

  String? _normalizeLanguage(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || !_allowedLanguages.contains(normalized)) {
      return null;
    }
    return normalized;
  }
}

class AppLocaleState extends Equatable {
  static const _unset = Object();

  final Locale locale;
  final bool isHydrating;
  final bool isSaving;
  final String? errorMessageKey;

  const AppLocaleState({
    required this.locale,
    this.isHydrating = false,
    this.isSaving = false,
    this.errorMessageKey,
  });

  AppLocaleState copyWith({
    Locale? locale,
    bool? isHydrating,
    bool? isSaving,
    Object? errorMessageKey = _unset,
    bool clearError = false,
  }) {
    return AppLocaleState(
      locale: locale ?? this.locale,
      isHydrating: isHydrating ?? this.isHydrating,
      isSaving: isSaving ?? this.isSaving,
      errorMessageKey: clearError
          ? null
          : identical(errorMessageKey, _unset)
          ? this.errorMessageKey
          : errorMessageKey as String?,
    );
  }

  @override
  List<Object?> get props => [locale, isHydrating, isSaving, errorMessageKey];
}
