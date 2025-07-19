import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GroupCard({super.key, required this.group, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    debugPrint('[GROUP-CARD] build() for ${group.id}, name=${group.name}');

    final isDisabled = onEdit == null && onDelete == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.group, size: 40),
          title: Text(group.name),
          subtitle: Text(group.description),
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
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!group.isDefault)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
