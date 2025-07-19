import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

class ProjectTile extends StatelessWidget {
  final Project project;
  final int groupCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const ProjectTile({
    super.key,
    required this.project,
    required this.groupCount,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.description),
            const SizedBox(height: 4),
            Text("Users: ${project.userRoles.length} • Groups: $groupCount"),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (!project.isDefault)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
