import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

enum _CameraMenuAction { view, edit, delete }

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
    final subtitle = camera.description.trim().isNotEmpty
        ? camera.description.trim()
        : camera.rtspUrl;

    return Card(
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
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<_CameraMenuAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case _CameraMenuAction.view:
                onTap?.call();
                break;
              case _CameraMenuAction.edit:
                onEdit?.call();
                break;
              case _CameraMenuAction.delete:
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _CameraMenuAction.view,
              enabled: onTap != null,
              child: const Text('View'),
            ),
            PopupMenuItem(
              value: _CameraMenuAction.edit,
              enabled: onEdit != null,
              child: const Text('Edit'),
            ),
            PopupMenuItem(
              value: _CameraMenuAction.delete,
              enabled: onDelete != null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
