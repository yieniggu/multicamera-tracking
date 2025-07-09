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

  List<Camera> cameras = [];
  bool isLoading = true;
  bool isGuest = false;

  Project? defaultProject;
  Group? defaultGroup;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkAuthStatus();
    await _loadDefaultProjectAndGroup();
    await _loadCameras();
  }

  Future<void> _checkAuthStatus() async {
    final user = _auth.currentUser;
    isGuest = user?.isAnonymous == true;
  }

  Future<void> _loadDefaultProjectAndGroup() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    defaultProject = await _initService.projectRepository.getDefaultProject();
    if (defaultProject != null) {
      defaultGroup = await _initService.groupRepository.getDefaultGroup(defaultProject!.id);
    }
  }

  Future<void> _loadCameras() async {
    final loaded = await _cameraRepo.getAll();
    setState(() {
      cameras = loaded;
      isLoading = false;
    });
  }

  Future<void> _addCamera(Camera camera) async {
    await _cameraRepo.save(camera);
    setState(() {
      cameras.add(camera);
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
          setState(() {
            final index = cameras.indexWhere((c) => c.id == updated.id);
            if (index != -1) {
              cameras[index] = updated;
            }
          });
        },
      ),
    );
  }

  Future<void> _deleteCamera(String id) async {
    await _cameraRepo.delete(id);
    setState(() {
      cameras.removeWhere((c) => c.id == id);
    });
  }

  void _showAddCameraSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(onCameraAdded: _addCamera),
    );
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
      body: Column(
        children: [
          if (defaultProject != null && defaultGroup != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Project: ${defaultProject!.name}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Group: ${defaultGroup!.name}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : cameras.isEmpty
                      ? const Center(child: Text("No cameras added yet."))
                      : ListView.builder(
                          itemCount: cameras.length,
                          itemBuilder: (context, index) {
                            final camera = cameras[index];
                            return Card(
                              child: ListTile(
                                leading: camera.thumbnailUrl != null
                                    ? Image.network(
                                        camera.thumbnailUrl!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image_not_supported),
                                      )
                                    : const Icon(Icons.videocam, size: 40),
                                title: Text(camera.name),
                                subtitle: Text(camera.rtspUrl),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editCamera(camera);
                                    } else if (value == 'delete') {
                                      _deleteCamera(camera.id);
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
                            );
                          },
                        ),
            ),
          ),
          if (isGuest)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login),
                label: const Text("Want to restore data anywhere? Log in"),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCameraSheet,
        child: const Icon(Icons.add),
        tooltip: "Add Camera",
      ),
    );
  }
}
