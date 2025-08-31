import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
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

class HomeScreen extends StatefulWidget {
  final bool isGuest;

  const HomeScreen({super.key, required this.isGuest});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = getIt<AuthRepository>();
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final projectBloc = context.read<ProjectBloc>();
    final groupBloc = context.read<GroupBloc>();
    final cameraBloc = context.read<CameraBloc>();

    // Load projects
    projectBloc.add(LoadProjects());

    // Wait for ProjectLoaded
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      return projectBloc.state is! ProjectsLoaded;
    });

    final projectState = projectBloc.state;
    if (projectState is! ProjectsLoaded) return;

    final allProjects = projectState.projects;

    // Load groups sequentially per project
    for (final project in allProjects) {
      groupBloc.add(LoadGroupsByProject(project.id));

      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        final groupState = groupBloc.state;
        if (groupState is GroupLoaded) {
          // Stop waiting when this project's groups are loaded (even if empty)
          return !groupState.grouped.containsKey(project.id);
        }
        return true;
      });
    }

    // Wait a little for UI sync (optional)
    await Future.delayed(const Duration(milliseconds: 100));

    // Load cameras for all groups across all projects
    final groupState = groupBloc.state;
    if (groupState is GroupLoaded) {
      for (final project in allProjects) {
        final groups = groupState.grouped[project.id] ?? [];
        for (final group in groups) {
          cameraBloc.add(LoadCamerasByGroup(group.projectId, group.id));
        }
      }
    }

    // Finish loading state
    if (mounted) {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _logout() async {
    // Tell the bloc. AuthGate will rebuild to Login.
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
    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectSheet(),
        tooltip: "Add Project",
        child: const Icon(Icons.add),
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
    );
  }
}
