import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/presentation/screens/camera_player_screen.dart';
import 'package:multicamera_tracking/presentation/screens/login_screen.dart';
import 'package:multicamera_tracking/presentation/widgets/add_camera_sheet.dart';
import 'package:multicamera_tracking/config/di.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;

  const HomeScreen({super.key, required this.isGuest});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = getIt<AuthRepository>();
  final _initService = getIt<InitUserDataService>();
  final _cameraRepo = getIt<CameraRepository>();

  bool isLoading = true;
  bool isGuest = false;

  List<Project> projects = [];
  Map<String, List<Group>> groupsByProject = {};
  Map<String, List<Camera>> camerasByGroup = {}; // key = "$projectId|$groupId"

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final user = _auth.currentUser;
    isGuest = user?.isAnonymous == true;

    final projRepo = _initService.projectRepository;
    final groupRepo = _initService.groupRepository;
    final camRepo = _cameraRepo;

    final loadedProjects = await projRepo.getAll();
    final Map<String, List<Group>> groupMap = {};
    final Map<String, List<Camera>> camMap = {};

    for (final project in loadedProjects) {
      final projectGroups = await groupRepo.getAllByProject(project.id);
      groupMap[project.id] = projectGroups;

      for (final group in projectGroups) {
        final groupCameras = await camRepo.getAllByGroup(project.id, group.id);
        camMap["${project.id}|${group.id}"] = groupCameras;
      }
    }

    setState(() {
      projects = loadedProjects;
      groupsByProject = groupMap;
      camerasByGroup = camMap;
      isLoading = false;
    });
  }

  Future<void> _addCamera(Camera camera) async {
    await _cameraRepo.save(camera);
    final key = "${camera.projectId}|${camera.groupId}";
    setState(() {
      camerasByGroup.putIfAbsent(key, () => []);
      camerasByGroup[key]!.add(camera);
    });
  }

  void _editCamera(Camera camera) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(
        existingCamera: camera,
        onCameraAdded: (updated) async {
          await _cameraRepo.save(updated);
          final key = "${updated.projectId}|${updated.groupId}";
          setState(() {
            final list = camerasByGroup[key];
            if (list != null) {
              final index = list.indexWhere((c) => c.id == updated.id);
              if (index != -1) list[index] = updated;
            }
          });
        },
      ),
    );
  }

  Future<void> _deleteCamera(String projectId, String groupId, String id) async {
    await _cameraRepo.deleteById(projectId, groupId, id);
    final key = "$projectId|$groupId";
    setState(() {
      camerasByGroup[key]?.removeWhere((c) => c.id == id);
    });
  }

  void _openCamera(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraPlayerScreen(camera: camera)),
    );
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

  void _showAddCameraSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(onCameraAdded: _addCamera),
    );
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? const Center(child: Text("No projects found."))
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, projectIndex) {
                    final project = projects[projectIndex];
                    final groups = groupsByProject[project.id] ?? [];

                    return ExpansionTile(
                      title: Text(project.name),
                      subtitle: Text(project.description),
                      children: groups.map((group) {
                        final camKey = "${project.id}|${group.id}";
                        final groupCameras = camerasByGroup[camKey] ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16),
                              child: Text(
                                "Group: ${group.name}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            ...groupCameras.map((camera) => Card(
                                  child: ListTile(
                                    leading: camera.thumbnailUrl != null
                                        ? Image.network(
                                            camera.thumbnailUrl!,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                          )
                                        : const Icon(Icons.videocam, size: 40),
                                    title: Text(camera.name),
                                    subtitle: Text(camera.rtspUrl),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editCamera(camera);
                                        } else if (value == 'delete') {
                                          _deleteCamera(project.id, group.id, camera.id);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _openCamera(camera),
                                  ),
                                )),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCameraSheet,
        child: const Icon(Icons.add),
        tooltip: "Add Camera",
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
