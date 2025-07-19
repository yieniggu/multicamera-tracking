import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';
import 'package:uuid/uuid.dart';

import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';

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
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final isEditing = widget.existingGroup != null;
      final id = isEditing ? widget.existingGroup!.id : const Uuid().v4();

      final user = getIt<AuthRepository>().currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("User not found. Try signing in again."),
            ),
          );
        }
        return;
      }

      final group = Group(
        id: id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isDefault: widget.existingGroup?.isDefault ?? false,
        projectId: widget.projectId,
        userRoles: isEditing
            ? widget.existingGroup!.userRoles
            : {user.id: AccessRole.admin},
        createdAt: widget.existingGroup?.createdAt ?? now,
        updatedAt: now,
      );

      final bloc = context.read<GroupBloc>();

      late final StreamSubscription sub;
      sub = bloc.stream.listen((state) {
        if (state is GroupLoaded) {
          sub.cancel();
          if (mounted) Navigator.pop(context);
        }
      });

      bloc.add(AddOrUpdateGroup(group));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? "Save Changes" : "Add Group"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
