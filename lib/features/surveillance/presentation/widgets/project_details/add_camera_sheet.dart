import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_state.dart';
import 'package:multicamera_tracking/shared/utils/app_mode.dart';
import 'package:uuid/uuid.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:collection/collection.dart';

class AddCameraSheet extends StatefulWidget {
  final Camera? existingCamera;
  final Project? initialProject;
  final Group? initialGroup;

  const AddCameraSheet({
    super.key,
    this.existingCamera,
    this.initialProject,
    this.initialGroup,
  });

  @override
  State<AddCameraSheet> createState() => _AddCameraSheetState();
}

class _AddCameraSheetState extends State<AddCameraSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _urlController;
  late final TextEditingController _thumbnailController;

  Project? _selectedProject;
  Group? _selectedGroup;

  @override
  void initState() {
    super.initState();

    final cam = widget.existingCamera;
    _nameController = TextEditingController(text: cam?.name ?? '');
    _descriptionController = TextEditingController(
      text: cam?.description ?? '',
    );
    _urlController = TextEditingController(text: cam?.rtspUrl ?? '');
    _thumbnailController = TextEditingController(text: cam?.thumbnailUrl ?? '');

    _selectedProject = widget.initialProject;
    _selectedGroup = widget.initialGroup;

    // Load groups if not locked and project ID is known
    final projectId = cam?.projectId ?? widget.initialProject?.id;
    if (_selectedGroup == null && projectId != null) {
      context.read<GroupBloc>().add(LoadGroupsByProject(projectId));
    }
  }

  void _onProjectChanged(Project? project, List<Group> allGroups) {
    setState(() {
      _selectedProject = project;
      final candidates = allGroups
          .where((g) => g.projectId == project?.id)
          .toList();
      _selectedGroup = candidates.isNotEmpty ? candidates.first : null;
    });
  }

  bool _isSubmitting = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProject == null || _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a project and group.")),
      );
      return;
    }

    setState(() => _isSubmitting = true); // start loading

    try {
      final now = DateTime.now();
      final isEditing = widget.existingCamera != null;
      final id = isEditing ? widget.existingCamera!.id : const Uuid().v4();

      final user = getIt<AuthRepository>().currentUser!;
      final camera = Camera(
        id: id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        rtspUrl: _urlController.text.trim(),
        thumbnailUrl: _thumbnailController.text.trim().isEmpty
            ? null
            : _thumbnailController.text.trim(),
        groupId: _selectedGroup!.id,
        projectId: _selectedProject!.id,
        userRoles: isEditing
            ? widget.existingCamera!.userRoles
            : {user.id: AccessRole.admin},
        createdAt: widget.existingCamera?.createdAt ?? now,
        updatedAt: now,
      );

      final bloc = context.read<CameraBloc>();

      late final StreamSubscription sub;
      sub = bloc.stream.listen((state) {
        if (state is CameraLoaded) {
          sub.cancel();
          if (mounted) Navigator.pop(context);
        }
      });

      bloc.add(AddOrUpdateCamera(camera));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.select<ProjectBloc, List<Project>>((bloc) {
      final state = bloc.state;
      return state is ProjectsLoaded ? state.projects : [];
    });

    final groupState = context.watch<GroupBloc>().state;
    final isLoading = projects.isEmpty || groupState is! GroupLoaded;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isEditing = widget.existingCamera != null;
    final isLocked =
        widget.initialProject != null && widget.initialGroup != null;

    // Ensure project is selected
    _selectedProject ??= isEditing
        ? projects.firstWhere(
            (p) => p.id == widget.existingCamera!.projectId,
            orElse: () => projects.first,
          )
        : projects.first;

    // All available groups for the selected project
    final allGroups = (groupState).grouped[_selectedProject!.id] ?? [];

    // Ensure group is selected
    _selectedGroup ??= isEditing
        ? allGroups.firstWhere(
            (g) => g.id == widget.existingCamera!.groupId,
            orElse: () => allGroups.first,
          )
        : allGroups.firstOrNull;

    final camState = context.watch<CameraBloc>().state;
    final currentCamCount =
        (camState is CameraLoaded &&
            _selectedProject != null &&
            _selectedGroup != null)
        ? camState.getCameras(_selectedProject!.id, _selectedGroup!.id).length
        : 0;

    final trial = isTrialLocalMode();
    final blocked = trial && !isEditing && currentCamCount >= 4;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "Edit Camera" : "Add New Camera",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              if (isLocked) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Project: ${_selectedProject?.name ?? ''}"),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Group: ${_selectedGroup?.name ?? ''}"),
                ),
              ] else ...[
                DropdownButtonFormField<Project>(
                  value: _selectedProject,
                  decoration: const InputDecoration(
                    labelText: "Select Project",
                  ),
                  items: projects
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (p) => _onProjectChanged(p, allGroups),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Group>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(labelText: "Select Group"),
                  items: allGroups
                      .map(
                        (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                      )
                      .toList(),
                  onChanged: (g) => setState(() => _selectedGroup = g),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Camera Name"),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? "Required" : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: "RTSP URL"),
                validator: (v) => v == null || !v.startsWith("rtsp://")
                    ? "Enter a valid RTSP URL"
                    : null,
              ),
              TextFormField(
                controller: _thumbnailController,
                decoration: const InputDecoration(
                  labelText: "Thumbnail URL (optional)",
                ),
              ),
              const SizedBox(height: 16),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Trial limit: max 4 cameras per group in guest mode.",
                        ),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _isSubmitting || blocked ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? "Save Changes" : "Add Camera"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
