import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/camera.dart';

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

  @override
  void initState() {
    super.initState();
    final cam = widget.existingCamera;

    _nameController = TextEditingController(text: cam?.name ?? '');
    _descriptionController = TextEditingController(text: cam?.description ?? '');
    _urlController = TextEditingController(text: cam?.rtspUrl ?? '');
    _thumbnailController = TextEditingController(text: cam?.thumbnailUrl ?? '');
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final isEditing = widget.existingCamera != null;
      final id = isEditing
          ? widget.existingCamera!.id
          : const Uuid().v4();

      final camera = Camera(
        id: id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        rtspUrl: _urlController.text.trim(),
        thumbnailUrl: _thumbnailController.text.trim().isEmpty
            ? null
            : _thumbnailController.text.trim(),
      );

      widget.onCameraAdded(camera);
      Navigator.pop(context);
    }
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Camera Name"),
                validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
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
                decoration: const InputDecoration(labelText: "Thumbnail URL (optional)"),
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
