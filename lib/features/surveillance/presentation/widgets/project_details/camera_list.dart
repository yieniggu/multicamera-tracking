import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/screens/camera_player_screen.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_camera_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/camera_card.dart';

class CameraList extends StatelessWidget {
  final String groupId;
  final String projectId;

  const CameraList({super.key, required this.groupId, required this.projectId});

  void _openCamera(BuildContext context, Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraPlayerScreen(camera: camera)),
    );
  }

  void _editCamera(BuildContext context, Camera camera) {
    final camState = context.read<CameraBloc>().state;

    // Retrieve the freshest camera state from the bloc
    final latestCam = (camState is CameraLoaded)
        ? camState
              .getCameras(camera.projectId, camera.groupId)
              .firstWhere((c) => c.id == camera.id, orElse: () => camera)
        : camera;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(existingCamera: latestCam),
    );
  }

  Future<void> _deleteCamera(BuildContext context, Camera camera) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Camera"),
        content: Text('Are you sure you want to delete "${camera.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<CameraBloc>().add(DeleteCamera(camera));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (context, camState) {
        if (camState is CameraLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (camState is CameraError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Error loading cameras:\n${camState.message}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (camState is! CameraLoaded) {
          return const Center(child: Text("No camera data available."));
        }

        final cameras = camState.grouped[projectId]?[groupId] ?? [];

        if (cameras.isEmpty) {
          return const Center(
            child: Text(
              "No cameras in this group.\nTap the '+' button to add one!",
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: cameras.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (_, i) {
            final cam = cameras[i];
            final isSaving = camState.isSaving(cam.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Opacity(
                opacity: isSaving ? 0.5 : 1.0,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    CameraCard(
                      camera: cam,
                      onTap: isSaving ? null : () => _openCamera(context, cam),
                      onEdit: isSaving ? null : () => _editCamera(context, cam),
                      onDelete: isSaving
                          ? null
                          : () => _deleteCamera(context, cam),
                    ),
                    if (isSaving)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
