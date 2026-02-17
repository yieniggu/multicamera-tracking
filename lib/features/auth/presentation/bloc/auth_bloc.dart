import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final RegisterWithEmailUseCase registerWithEmailUseCase;
  final SignInAnonymouslyUseCase signInAnonymouslyUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final InitUserDataUseCase initUserDataUseCase;
  final MigrateGuestDataUseCase migrateGuestDataUseCase;
  final AppMode appMode;
  late final StreamSubscription _authSub;

  AuthBloc({
    required this.signInWithEmailUseCase,
    required this.registerWithEmailUseCase,
    required this.signInAnonymouslyUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.initUserDataUseCase,
    required this.migrateGuestDataUseCase,
    required this.appMode,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignedInWithEmail>(_onSignedInWithEmail);
    on<AuthRegisteredWithEmail>(_onRegisteredWithEmail);
    on<AuthSignedInAnonymously>(_onSignedInAnonymously);
    on<AuthSignedOut>(_onSignedOut);

    _authSub = getIt<AuthRepository>().authStateChanges().listen((_) {
      add(AuthCheckRequested());
    });
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    return super.close();
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("[AUTH-BLOC]onCheckRequested: starting auth check");
    final user = getCurrentUserUseCase();
    if (user != null) {
      debugPrint("[AUTH-BLOC]onCheckRequested: found user: ${user.toString()}");
      debugPrint(
        "[AUTH-BLOC]onCheckRequested: starting init user data use case",
      );

      await initUserDataUseCase();

      final isGuest = user.isAnonymous;
      if (isGuest) {
        appMode.enterGuest();
      } else {
        appMode.enterRemote();
      }

      // Update prefs to stay in sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', isGuest);

      emit(AuthAuthenticated(user, isGuest: isGuest));
    } else {
      debugPrint("[AUTH-BLOC]onCheckRequested: no user found");
      appMode.enterGuest();
      emit(AuthUnauthenticated());
    }
    debugPrint("[AUTH-BLOC]onCheckRequested: ending auth check");
  }

  Future<void> _onSignedInWithEmail(
    AuthSignedInWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("[AUTH-BLOC]onSignedInWithEmail: starting email sigIn");
    emit(AuthLoading());
    try {
      final user = await signInWithEmailUseCase(event.email, event.password);
      if (user != null) {
        debugPrint(
          "[AUTH-BLOC]onCheckRequested: found user: ${user.toString()}",
        );

        appMode.enterRemote();

        await initUserDataUseCase();
        emit(AuthAuthenticated(user, isGuest: false));
      } else {
        debugPrint("[AUTH-BLOC]onCheckRequested: sign in failed");

        emit(const AuthFailure("Sign in failed"));
      }
    } catch (e) {
      debugPrint(
        "[AUTH-BLOC]onCheckRequested: signIn error catched: ${e.toString()}",
      );
      debugPrintStack();
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRegisteredWithEmail(
    AuthRegisteredWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("[AUTH-BLOC]onRegisterWithEmail: starting email register");

    emit(AuthLoading());
    try {
      final user = await registerWithEmailUseCase(event.email, event.password);
      if (user != null) {
        debugPrint(
          "[AUTH-BLOC]onRegisterWithEmail: registered new user: ${user.toString()}",
        );

        appMode.enterRemote();

        // Optionally migrate guest data
        if (event.shouldMigrateGuestData) {
          debugPrint("[AUTH-BLOC]onRegisterWithEmail: will migrate data now..");
          await migrateGuestDataUseCase();
        }

        debugPrint(
          "[AUTH-BLOC]onRegisterWithEmail: starting init user data use case",
        );
        await initUserDataUseCase();
        emit(AuthAuthenticated(user, isGuest: false));
      } else {
        debugPrint("[AUTH-BLOC]onRegisterWithEmail: registration failed");
        emit(const AuthFailure("Registration failed"));
      }
    } catch (e) {
      debugPrint(
        "[AUTH-BLOC]onRegisterWithEmail: registration exception catched",
      );
      debugPrintStack();
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignedInAnonymously(
    AuthSignedInAnonymously event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("[AUTH-BLOC]onSignedInAnonymousle: starting anonymous signIn");

    emit(AuthLoading());
    try {
      final user = await signInAnonymouslyUseCase();
      if (user != null) {
        debugPrint(
          "[AUTH-BLOC]onSignedInAnonymousle: signedIn with user: ${user.toString()}",
        );
        debugPrint(
          "[AUTH-BLOC]onSignedInAnonymousle: starting initUserDataUseCase",
        );

        appMode.enterGuest();

        await initUserDataUseCase();
        emit(AuthAuthenticated(user, isGuest: true));
      } else {
        debugPrint("[AUTH-BLOC]onSignedInAnonymousle: anonymous signIn Failed");
        emit(const AuthFailure("Guest login failed"));
      }
    } catch (e) {
      debugPrint(
        "[AUTH-BLOC]onSignedInAnonymousle: anonymous signIn exception catched",
      );
      debugPrintStack();
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignedOut(
    AuthSignedOut event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("[AUTH-BLOC]onSignedOut: starting signOut");
    emit(AuthLoading());
    try {
      await signOutUseCase();

      // ensure we switch back to local mode after logout
      appMode.enterGuest();

      debugPrint("[AUTH-BLOC]onSignedOut: user signed out");
      emit(AuthUnauthenticated());
    } catch (e) {
      debugPrint("[AUTH-BLOC]onSignedOut: signOut exception catched");
      debugPrintStack();
      emit(AuthFailure("Sign out failed"));
    }
  }
}
