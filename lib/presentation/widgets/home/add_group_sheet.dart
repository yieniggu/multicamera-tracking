import 'package:flutter/material.dart';
import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/access_role.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';

class AddGroupSheet extends StatefulWidget {
  final String projectId;
  final Group? existingGroup;

  const AddGroupSheet({super.key, required this.projectId, this.existingGroup});

  @override
  State<AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends State<AddGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingGroup?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingGroup?.description ?? '',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final isEditing = widget.existingGroup != null;
    final id = isEditing ? widget.existingGroup!.id : const Uuid().v4();

    final user = getIt<AuthRepository>().currentUser!;

    final group = Group(
      id: id,
      name: _nameController.text.trim(),
      isDefault: widget.existingGroup?.isDefault ?? false,
      description: _descriptionController.text.trim(),
      projectId: widget.projectId,
      userRoles: isEditing
          ? widget.existingGroup!.userRoles
          : {user.id: AccessRole.admin},
      createdAt: widget.existingGroup?.createdAt ?? now,
      updatedAt: now,
    );

    final manager = Provider.of<ProjectManager>(context, listen: false);
    await manager.addOrUpdateGroup(group);

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
    final isEditing = widget.existingGroup != null;

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
                isEditing ? "Edit Group" : "Add New Group",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Group Name"),
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
                child: Text(isEditing ? "Save Changes" : "Add Group"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
