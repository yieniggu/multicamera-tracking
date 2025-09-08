import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

class ProjectTile extends StatelessWidget {
  final Project project;
  final int? groupCount; // null → show placeholder
  final bool disabled; // disables tile interactions/menus
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const ProjectTile({
    super.key,
    required this.project,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.groupCount,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(project.description),
        const SizedBox(height: 4),
        Text(
          "Users: ${project.userRoles.length} • Groups: ${groupCount == null ? '—' : groupCount}",
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          title: Text(project.name),
          subtitle: subtitle,
          trailing: disabled
              ? const Icon(Icons.more_vert, color: Colors.grey)
              : PopupMenuButton<String>(
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
          onTap: disabled ? null : onTap,
        ),
      ),
    );
  }
}
