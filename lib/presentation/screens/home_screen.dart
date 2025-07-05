import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/presentation/screens/camera_player_screen.dart';
import 'package:multicamera_tracking/presentation/widgets/add_camera_sheet.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Camera> cameras = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  void _editCamera(Camera camera) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(
        existingCamera: camera,
        onCameraAdded: (updated) async {
          final repo = getIt<CameraRepository>();
          await repo.save(updated);
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
    final repo = getIt<CameraRepository>();
    await repo.delete(id);
    setState(() {
      cameras.removeWhere((c) => c.id == id);
    });
  }

  Future<void> _loadCameras() async {
    final repo = getIt<CameraRepository>(); // ✅ inject dependency
    final loaded = await repo.getAll();
    setState(() {
      cameras = loaded;
      isLoading = false;
    });
  }

  Future<void> _addCamera(Camera camera) async {
    final repo = getIt<CameraRepository>(); // ✅ inject again
    await repo.save(camera);
    setState(() {
      cameras.add(camera);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera Viewer")),
      body: Padding(
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
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCameraSheet,
        child: const Icon(Icons.add),
        tooltip: "Add Camera",
      ),
    );
  }
}
