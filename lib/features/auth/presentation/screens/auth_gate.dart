import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/shared/presentation/screen/home_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "[AUTH-GATE] Building... current state: ${context.watch<AuthBloc>().state}",
    );
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        debugPrint("[AUTH-GATE] BlocBuilder triggered. State: $state");
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AuthAuthenticated) {
          debugPrint(
            "[AUTH-GATE] User authenticated, loading home screen. (isguest=${state.isGuest})",
          );
          return HomeScreen(isGuest: state.isGuest);
        }

        debugPrint("[AUTH-GATE] User unaauthenticated, loading Login screen.");
        return const LoginScreen();
      },
    );
  }
}
