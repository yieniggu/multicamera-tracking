import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/migration_conflict_screen.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/presentation/screen/initial_home_shell_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserId;
  bool _isShowingMigrationDialog = false;

  void _showMigrationDialog(AuthAuthenticated state) {
    if (_isShowingMigrationDialog ||
        !state.requiresMigrationConfirmation ||
        state.migrationSourceUserId == null) {
      return;
    }
    _isShowingMigrationDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isShowingMigrationDialog = false;
        return;
      }
      debugPrint(
        "[AUTH-GATE] Showing migration dialog for source=${state.migrationSourceUserId}",
      );
      try {
        final plan = await showMigrationConflictScreen(
          context: context,
          preview:
              state.migrationPreview ??
              const GuestMigrationPreview(projectConflicts: []),
          initialValidationIssues: state.migrationValidationIssues,
        );
        if (!mounted) return;
        final authBloc = context.read<AuthBloc>();
        if (plan != null) {
          debugPrint("[AUTH-GATE] Migration plan confirmed by user");
          authBloc.add(
            AuthForcedGuestMigrationRequested(
              sourceUserId: state.migrationSourceUserId!,
              plan: plan,
            ),
          );
        } else {
          debugPrint("[AUTH-GATE] Migration dialog dismissed/skipped");
          authBloc.add(AuthMigrationPromptDismissed());
        }
      } finally {
        _isShowingMigrationDialog = false;
      }
    });
  }

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
        final projectBloc = context.read<ProjectBloc>();
        final groupBloc = context.read<GroupBloc>();
        final cameraBloc = context.read<CameraBloc>();

        if (state is AuthUnauthenticated) {
          _lastUserId = null;
          projectBloc.add(ResetProjects());
          groupBloc.add(ResetGroups());
          cameraBloc.add(const ResetCameras());
          return;
        }

        if (state is AuthAuthenticated) {
          final nextUserId = state.user.id;
          if (_lastUserId != nextUserId) {
            _lastUserId = nextUserId;
            projectBloc.add(ResetProjects());
            groupBloc.add(ResetGroups());
            cameraBloc.add(const ResetCameras());
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
            _showMigrationDialog(state);
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
