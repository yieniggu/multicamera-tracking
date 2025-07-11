import 'package:flutter/material.dart';
import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/entities/access_role.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';

class ProjectSheet extends StatefulWidget {
  final Project? existingProject;

  const ProjectSheet({super.key, this.existingProject});

  @override
  State<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<ProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingProject?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingProject?.description ?? '',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final isEditing = widget.existingProject != null;
    final id = isEditing ? widget.existingProject!.id : const Uuid().v4();

    final user = getIt<AuthRepository>().currentUser!;
    final manager = Provider.of<ProjectManager>(context, listen: false);

    final project = Project(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      userRoles: isEditing
          ? widget.existingProject!.userRoles
          : {user.id: AccessRole.admin},
      isDefault: widget.existingProject?.isDefault ?? false,
      createdAt: widget.existingProject?.createdAt ?? now,
      updatedAt: now,
    );

    await manager.addOrUpdateProject(project);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProject != null;

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
                isEditing ? "Edit Project" : "Add New Project",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit,
                child: Text(isEditing ? "Save Changes" : "Add Project"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
