import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/shared/presentation/screen/initial_home_shell_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "[AUTH-GATE] Building... current state: ${context.watch<AuthBloc>().state}",
    );
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          _lastUserId = null;
          context.read<ProjectBloc>().add(ResetProjects());
          context.read<GroupBloc>().add(ResetGroups());
          context.read<CameraBloc>().add(const ResetCameras());
          return;
        }

        if (state is AuthAuthenticated) {
          final nextUserId = state.user.id;
          if (_lastUserId != nextUserId) {
            _lastUserId = nextUserId;
            context.read<ProjectBloc>().add(ResetProjects());
            context.read<GroupBloc>().add(ResetGroups());
            context.read<CameraBloc>().add(const ResetCameras());
          }
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
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
            return InitialHomeShellScreen(isGuest: state.isGuest);
          }

          debugPrint(
            "[AUTH-GATE] User unaauthenticated, loading Login screen.",
          );
          return const LoginScreen();
        },
      ),
    );
  }
}
