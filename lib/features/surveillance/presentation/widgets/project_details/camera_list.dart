import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_state.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_state.dart';

import 'package:multicamera_tracking/features/surveillance/presentation/screens/camera_viewer_screen.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_camera_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/camera_card.dart';

class CameraList extends StatefulWidget {
  final String projectId;
  final String groupId;

  const CameraList({super.key, required this.projectId, required this.groupId});

  @override
  State<CameraList> createState() => _CameraListState();
}

class _CameraListState extends State<CameraList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant CameraList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final groupChanged =
        oldWidget.projectId != widget.projectId ||
        oldWidget.groupId != widget.groupId;

    if (groupChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  void _load() {
    context.read<CameraBloc>().add(
      LoadCamerasByGroup(projectId: widget.projectId, groupId: widget.groupId),
    );
  }

  Project? _resolveProject() {
    final s = context.read<ProjectBloc>().state;
    if (s is! ProjectsLoaded) return null;
    try {
      return s.projects.firstWhere((p) => p.id == widget.projectId);
    } catch (_) {
      return null;
    }
  }

  Group? _resolveGroup() {
    final s = context.read<GroupBloc>().state;
    if (s is! GroupLoaded) return null;
    final groups = s.getGroups(widget.projectId);
    try {
      return groups.firstWhere((g) => g.id == widget.groupId);
    } catch (_) {
      return null;
    }
  }

  void _openViewer(Camera cam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraViewerScreen(
          projectId: widget.projectId,
          initialGroupId: widget.groupId,
          initialCameraId: cam.id,
        ),
      ),
    );
  }

  void _editCamera(Camera cam) {
    final project = _resolveProject();
    final group = _resolveGroup();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCameraSheet(
        existingCamera: cam,
        initialProject: project,
        initialGroup: group,
      ),
    );
  }

  Future<void> _deleteCamera(Camera cam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Camera"),
        content: Text('Are you sure you want to delete "${cam.name}"?'),
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
      context.read<CameraBloc>().add(DeleteCamera(cam));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (context, state) {
        if (state is CameraInitial || state is CameraLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CameraError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Error loading cameras:\n${state.message}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          );
        }

        if (state is! CameraLoaded) {
          return const Center(child: Text("No camera data available."));
        }

        final isGroupLoading = state.isLoadingGroup(
          widget.projectId,
          widget.groupId,
        );
        final cameras = state.getCameras(widget.projectId, widget.groupId);

        if (cameras.isEmpty && !isGroupLoading) {
          return const Center(
            child: Text(
              "No cameras in this group.\nTap the '+' button to add one!",
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: [
            if (isGroupLoading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: ListView.builder(
                itemCount: cameras.length,
                itemBuilder: (_, i) {
                  final cam = cameras[i];
                  final isSaving = state.isSaving(cam.id);

                  return Opacity(
                    opacity: isSaving ? 0.5 : 1.0,
                    child: CameraCard(
                      key: ValueKey(cam.id),
                      camera: cam,
                      onTap: isSaving ? null : () => _openViewer(cam),
                      onEdit: isSaving ? null : () => _editCamera(cam),
                      onDelete: isSaving ? null : () => _deleteCamera(cam),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
