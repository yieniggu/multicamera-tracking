import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:multicamera_tracking/data/models/camera_model.dart';
// import 'package:multicamera_tracking/data/models/group_model.dart';
// import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:provider/provider.dart';

import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/presentation/screens/login_screen.dart';
import 'package:multicamera_tracking/presentation/screens/project_details_screen.dart';
import 'package:multicamera_tracking/presentation/widgets/home/project_tile.dart';
import 'package:multicamera_tracking/presentation/widgets/home/add_project_sheet.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;

  const HomeScreen({super.key, required this.isGuest});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = getIt<AuthRepository>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint("[HOME] Loading project data...");
    await context.read<ProjectManager>().loadAll();
    debugPrint("[HOME] Done loading.");
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _goToProjectDetail(Project project) {
    final manager = context.read<ProjectManager>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: manager,
          child: ProjectDetailsScreen(project: project),
        ),
      ),
    );
  }

  void _showProjectSheet({Project? existingProject}) {
    final manager = context.read<ProjectManager>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: manager,
        child: ProjectSheet(existingProject: existingProject),
      ),
    );
  }

  Future<void> _deleteProject(BuildContext context, Project project) async {
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
      await context.read<ProjectManager>().deleteProject(project.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProjectManager>();
    final projects = manager.projects;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera Viewer"),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.delete_forever),
          //   tooltip: 'Clear Hive',
          //   onPressed: () async {
          //     await Hive.box<ProjectModel>('projects').clear();
          //     await Hive.box<GroupModel>('groups').clear();
          //     await Hive.box<CameraModel>('cameras').clear();
          //     debugPrint("[DEV] Cleared Hive storage");

          //     manager.resetLoadedFlag(); // reset so loadAll runs again
          //     await manager.loadAll();
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: manager.isLoading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
          ? const Center(child: Text("No projects found."))
          : ListView.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final groupCount = manager.groupCount(project.id);

                return ProjectTile(
                  project: project,
                  groupCount: groupCount,
                  onTap: () => _goToProjectDetail(project),
                  onEdit: () => _showProjectSheet(existingProject: project),
                  onDelete: project.isDefault
                      ? null
                      : () => _deleteProject(context, project),
                );
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
