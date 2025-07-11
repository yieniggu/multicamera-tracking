import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/access_role.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';

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
  }

  void _onProjectChanged(Project? project, List<Group> groups) {
    setState(() {
      _selectedProject = project;
      final matchingGroups = groups
          .where((g) => g.projectId == project?.id)
          .toList();
      _selectedGroup = matchingGroups.firstOrNull;
    });
  }

  void _submit(ProjectManager manager) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null || _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a project and group.")),
      );
      return;
    }

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

    await manager.addOrUpdateCamera(camera);
    if (mounted) Navigator.pop(context);
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
    final manager = context.watch<ProjectManager>();
    final projects = manager.projects;
    final groups = manager.groups;

    final isEditing = widget.existingCamera != null;
    final isLocked =
        widget.initialProject != null && widget.initialGroup != null;

    // If not locked and nothing is selected yet, initialize defaults
    _selectedProject ??= projects.firstWhere(
      (p) => p.id == widget.existingCamera!.projectId,
      orElse: () => projects.isNotEmpty
          ? projects.first
          : throw Exception("No projects available"),
    );

    final filteredGroups = groups
        .where((g) => g.projectId == _selectedProject?.id)
        .toList();

    _selectedGroup ??= groups.firstWhere(
      (g) => g.id == widget.existingCamera!.groupId,
      orElse: () => filteredGroups.isNotEmpty
          ? filteredGroups.first
          : throw Exception("No groups available for selected project"),
    );

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
                  onChanged: (project) => _onProjectChanged(project, groups),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Group>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(labelText: "Select Group"),
                  items: filteredGroups
                      .map(
                        (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                      )
                      .toList(),
                  onChanged: (group) => setState(() => _selectedGroup = group),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Camera Name"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
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
              ElevatedButton(
                onPressed: () => _submit(manager),
                child: Text(isEditing ? "Save Changes" : "Add Camera"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
