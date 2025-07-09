import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';

class AddCameraSheet extends StatefulWidget {
  final Camera? existingCamera;
  final void Function(Camera camera) onCameraAdded;

  const AddCameraSheet({
    super.key,
    required this.onCameraAdded,
    this.existingCamera,
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

  List<Project> _projects = [];
  List<Group> _groups = [];
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

    _loadProjectsAndGroups();
  }

  Future<void> _loadProjectsAndGroups() async {
    final projectRepo = getIt<ProjectRepository>();
    final groupRepo = getIt<GroupRepository>();

    final allProjects = await projectRepo.getAll();
    final allGroups = await groupRepo.getAll();

    setState(() {
      _projects = allProjects;
      if (_projects.isNotEmpty) {
        _selectedProject = _projects.firstWhere(
          (p) => p.id == widget.existingCamera?.groupId,
          orElse: () => _projects.first,
        );
      }

      _groups = allGroups;
      if (_groups.isNotEmpty && _selectedProject != null) {
        _selectedGroup = _groups.firstWhere(
          (g) => g.id == widget.existingCamera?.groupId,
          orElse: () => _groups.firstWhere(
            (g) => g.projectId == _selectedProject!.id,
            orElse: () => _groups.first,
          ),
        );
      }
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedGroup == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please select a group.")));
        return;
      }

      final now = DateTime.now();
      final isEditing = widget.existingCamera != null;
      final id = isEditing ? widget.existingCamera!.id : const Uuid().v4();

      final camera = Camera(
        id: id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        rtspUrl: _urlController.text.trim(),
        thumbnailUrl: _thumbnailController.text.trim().isEmpty
            ? null
            : _thumbnailController.text.trim(),
        groupId: _selectedGroup!.id,
        userRoles: widget.existingCamera?.userRoles ?? {},
        createdAt: widget.existingCamera?.createdAt ?? now,
        updatedAt: now,
      );

      widget.onCameraAdded(camera);
      Navigator.pop(context);
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
    final isEditing = widget.existingCamera != null;

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
              DropdownButtonFormField<Project>(
                value: _selectedProject,
                decoration: const InputDecoration(labelText: "Select Project"),
                items: _projects
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (project) {
                  setState(() {
                    _selectedProject = project;
                    _selectedGroup = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Group>(
                value: _selectedGroup,
                decoration: const InputDecoration(labelText: "Select Group"),
                items: _groups
                    .where((g) => g.projectId == _selectedProject?.id)
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: (group) {
                  setState(() => _selectedGroup = group);
                },
              ),
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
                onPressed: _submit,
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
