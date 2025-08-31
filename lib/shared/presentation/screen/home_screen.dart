import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';

import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_state.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/screens/project_details_screen.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/home/add_project_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/home/project_tile.dart';
import 'package:multicamera_tracking/shared/constants/quota.dart';

import 'package:multicamera_tracking/shared/utils/app_mode.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;

  const HomeScreen({super.key, required this.isGuest});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;
  // Track which (projectId|groupId) have had their cameras requested
  final Set<String> _requestedCameraForGroup = {};

  @override
  void initState() {
    super.initState();
    // Kick off projects; rest cascades from listeners below
    context.read<ProjectBloc>().add(LoadProjects());
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _logout() async {
    if (mounted) {
      context.read<AuthBloc>().add(AuthSignedOut());
    }
  }

  void _goToProjectDetail(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: project)),
    );
  }

  void _showProjectSheet({Project? existingProject}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProjectSheet(existingProject: existingProject),
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Project"),
        content: const Text("Are you sure you want to delete this project?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<ProjectBloc>().add(DeleteProject(project.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrial = isTrialLocalMode();
    final projectsCount = context.select<ProjectBloc, int>((bloc) {
      final s = bloc.state;
      return s is ProjectsLoaded ? s.projects.length : 0;
    });

    return MultiBlocListener(
      listeners: [
        // When projects arrive, request groups for each
        BlocListener<ProjectBloc, ProjectState>(
          listenWhen: (prev, curr) => curr is ProjectsLoaded,
          listener: (context, state) {
            final projects = (state as ProjectsLoaded).projects;
            for (final p in projects) {
              context.read<GroupBloc>().add(LoadGroupsByProject(p.id));
            }
            if (mounted) setState(() => _isLoadingData = false);
          },
        ),
        // When groups arrive for any project, request cameras per group (once)
        BlocListener<GroupBloc, GroupState>(
          listenWhen: (prev, curr) => curr is GroupLoaded,
          listener: (context, state) {
            final grouped = (state as GroupLoaded).grouped;
            final camBloc = context.read<CameraBloc>();
            grouped.forEach((projectId, groups) {
              for (final g in groups) {
                final key = '$projectId|${g.id}';
                if (_requestedCameraForGroup.add(key)) {
                  camBloc.add(LoadCamerasByGroup(projectId, g.id));
                }
              }
            });
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Camera Viewer"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : BlocBuilder<ProjectBloc, ProjectState>(
                builder: (context, projectState) {
                  if (projectState is ProjectsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (projectState is ProjectsLoaded) {
                    final projects = projectState.projects;
                    if (projects.isEmpty) {
                      return const Center(child: Text("No projects found."));
                    }

                    return BlocBuilder<GroupBloc, GroupState>(
                      builder: (context, groupState) {
                        return ListView.builder(
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            final groupCount = (groupState is GroupLoaded)
                                ? groupState.grouped[project.id]?.length ?? 0
                                : 0;

                            return ProjectTile(
                              project: project,
                              groupCount: groupCount,
                              onTap: () => _goToProjectDetail(project),
                              onEdit: () =>
                                  _showProjectSheet(existingProject: project),
                              onDelete: project.isDefault
                                  ? null
                                  : () => _deleteProject(project),
                            );
                          },
                        );
                      },
                    );
                  }

                  if (projectState is ProjectsError) {
                    return Center(child: Text(projectState.message));
                  }

                  return const SizedBox.shrink();
                },
              ),
        floatingActionButton: Builder(
          builder: (ctx) {
            void _onFabPressed() {
              final isTrial = isTrialLocalMode();
              final s = ctx.read<ProjectBloc>().state;
              final count = s is ProjectsLoaded ? s.projects.length : 0;

              if (isTrial && count >= Quota.projects) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Trial limit: max ${Quota.projects} project in guest mode.",
                    ),
                  ),
                );
                return;
              }
              _showProjectSheet();
            }

            return FloatingActionButton(
              onPressed: _onFabPressed,
              tooltip: isTrial
                  ? "Trial: $projectsCount/${Quota.projects} project"
                  : "Add Project",
              child: const Icon(Icons.add),
            );
          },
        ),

        bottomNavigationBar: widget.isGuest
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: _navigateToLogin,
                  icon: const Icon(Icons.login),
                  label: const Text("Want to restore data anywhere? Log in"),
                ),
              )
            : null,
      ),
    );
  }
}
