import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

class EditProjectDialog extends StatefulWidget {
  final Project project;
  final void Function(String name, String description) onSubmit;

  const EditProjectDialog({
    super.key,
    required this.project,
    required this.onSubmit,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.project.name);
    descCtrl = TextEditingController(text: widget.project.description);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Project"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: "Name"),
          ),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: "Description"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmit(nameCtrl.text.trim(), descCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
