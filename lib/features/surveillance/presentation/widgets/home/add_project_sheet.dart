import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_state.dart';
import 'package:uuid/uuid.dart';

import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_event.dart';
import 'package:multicamera_tracking/shared/utils/app_mode.dart';

class AddProjectSheet extends StatefulWidget {
  final Project? existingProject;

  const AddProjectSheet({super.key, this.existingProject});

  @override
  State<AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<AddProjectSheet> {
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

    final bloc = context.read<ProjectBloc>();

    late final StreamSubscription sub;
    sub = bloc.stream.listen((state) {
      if (!mounted) return;
      if (state is ProjectsLoaded) {
        sub.cancel();
        Navigator.pop(context);
      } else if (state is ProjectsError) {
        sub.cancel();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message)));
      }
    });

    bloc.add(AddOrUpdateProject(project));

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
    final projects = context.select<ProjectBloc, List<Project>>((bloc) {
      final s = bloc.state;
      return s is ProjectsLoaded ? s.projects : <Project>[];
    });
    final trial = isTrialLocalMode();
    final blocked = trial && !isEditing && projects.isNotEmpty;

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
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Trial limit: only 1 project allowed in guest mode.",
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: blocked ? null : _submit,
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
