import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

class CameraCard extends StatelessWidget {
  final Camera camera;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CameraCard({
    super.key,
    required this.camera,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onEdit == null && onDelete == null && onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          onTap: onTap,
          leading: camera.thumbnailUrl != null
              ? Image.network(
                  camera.thumbnailUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                )
              : const Icon(Icons.videocam, size: 40),
          title: Text(camera.name),
          subtitle: Text(camera.rtspUrl),
          trailing: isDisabled
              ? const Icon(Icons.more_vert, color: Colors.grey)
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
        ),
      ),
    );
  }
}
