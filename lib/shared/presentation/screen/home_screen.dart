import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/preferences_screen.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/register_screen.dart';

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

import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/config/di.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  final bool showGuestLoginCta;

  const HomeScreen({
    super.key,
    required this.isGuest,
    this.showGuestLoginCta = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;

  // Track which (projectId|groupId) have had their cameras requested
  final Set<String> _requestedCameraForGroup = {};
  final Set<String> _requestedGroupsForProject = {};
  final Map<String, int> _groupCountCache = {};

  @override
  void initState() {
    super.initState();
    // Kick off projects; rest cascades from listeners below
    context.read<ProjectBloc>().add(LoadProjects());
  }

  void _navigateToLogin() {
    if (widget.isGuest && !widget.showGuestLoginCta) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const RegisterScreen(
            enableGuestMigration: true,
            showAlreadyHaveAccountAction: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoginScreen(enableGuestMigration: widget.isGuest),
      ),
    );
  }

  void _openPreferences() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreferencesScreen(isGuest: widget.isGuest),
      ),
    );
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

    if (!mounted) return;

    if (confirm == true) {
      context.read<ProjectBloc>().add(DeleteProject(project.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrial = getIt<AppMode>().isTrial;
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

            // Request groups only for projects we've never requested before
            for (final p in projects) {
              if (_requestedGroupsForProject.add(p.id)) {
                context.read<GroupBloc>().add(LoadGroupsByProject(p.id));
              }
            }

            // Clean up removed projects
            final currentIds = projects.map((p) => p.id).toSet();
            _requestedGroupsForProject.removeWhere(
              (pid) => !currentIds.contains(pid),
            );

            if (mounted) setState(() => _isLoadingData = false);
          },
        ),

        // When groups arrive for any project, request cameras per group (once)
        BlocListener<GroupBloc, GroupState>(
          listenWhen: (prev, curr) => curr is GroupLoaded,
          listener: (context, state) {
            final grouped = (state as GroupLoaded).grouped;

            // cache group counts so tiles never fall back to 0 while a reload runs
            grouped.forEach((projectId, groups) {
              _groupCountCache[projectId] = groups.length;
            });

            final camBloc = context.read<CameraBloc>();
            grouped.forEach((projectId, groups) {
              for (final g in groups) {
                final key = '$projectId|${g.id}';
                if (_requestedCameraForGroup.add(key)) {
                  camBloc.add(
                    LoadCamerasByGroup(projectId: projectId, groupId: g.id),
                  );
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
              key: const Key('home_settings_button'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Preferences',
              onPressed: _openPreferences,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : BlocBuilder<ProjectBloc, ProjectState>(
                      builder: (context, projectState) {
                        if (projectState is ProjectsLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (projectState is ProjectsLoaded) {
                          final projects = projectState.projects;
                          if (projects.isEmpty) {
                            return const Center(
                              child: Text("No projects found."),
                            );
                          }

                          return BlocBuilder<GroupBloc, GroupState>(
                            builder: (context, groupState) {
                              return ListView.builder(
                                itemCount: projects.length,
                                itemBuilder: (context, index) {
                                  final project = projects[index];

                                  final isSavingTile = projectState.isSaving(
                                    project.id,
                                  );

                                  final hasGroupData =
                                      (groupState is GroupLoaded)
                                      ? groupState.grouped.containsKey(
                                          project.id,
                                        )
                                      : false;

                                  // Disable while saving OR until this project's groups arrive
                                  final disabled =
                                      isSavingTile || !hasGroupData;

                                  // Use cached count if available
                                  final computedGroupCount =
                                      (groupState is GroupLoaded)
                                      ? (groupState
                                                .grouped[project.id]
                                                ?.length ??
                                            _groupCountCache[project.id])
                                      : _groupCountCache[project.id];

                                  return ProjectTile(
                                    project: project,
                                    onTap: () => _goToProjectDetail(project),
                                    onEdit: () => _showProjectSheet(
                                      existingProject: project,
                                    ),
                                    onDelete: project.isDefault
                                        ? null
                                        : () => _deleteProject(project),
                                    groupCount:
                                        disabled && computedGroupCount == null
                                        ? null
                                        : computedGroupCount,
                                    disabled: disabled,
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
            ),
            if (widget.isGuest && !widget.showGuestLoginCta)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      key: const Key('guest_link_account_cta'),
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _navigateToLogin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                              children: [
                                TextSpan(
                                  text: "Link an account",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(
                                  text: " to keep your data on all devices.",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (ctx) {
            void onFabPressed() {
              final isTrial = getIt<AppMode>().isTrial;
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

            return Padding(
              padding: EdgeInsets.only(
                bottom: widget.isGuest && !widget.showGuestLoginCta ? 56 : 0,
              ),
              child: FloatingActionButton(
                onPressed: onFabPressed,
                tooltip: isTrial
                    ? "Trial: $projectsCount/${Quota.projects} project"
                    : "Add Project",
                child: const Icon(Icons.add),
              ),
            );
          },
        ),
        bottomNavigationBar: widget.isGuest && widget.showGuestLoginCta
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
