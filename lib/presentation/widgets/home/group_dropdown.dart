import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';

class GroupDropdown extends StatelessWidget {
  final List<Group> groups;
  final Map<String, int> cameraCounts; // groupId → # of cameras
  final void Function(Group) onSelect;
  final void Function(Group) onEdit;
  final void Function(Group) onDelete;

  const GroupDropdown({
    super.key,
    required this.groups,
    required this.cameraCounts,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Group>(
      decoration: const InputDecoration(labelText: 'Select Group'),
      items: groups.map((group) {
        final cameraCount = cameraCounts[group.id] ?? 0;

        return DropdownMenuItem<Group>(
          value: group,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(group.name)),
              Text("👥 ${group.userRoles.length} 📷 $cameraCount"),
            ],
          ),
        );
      }).toList(),
      onChanged: (selected) {
        if (selected != null) onSelect(selected);
      },
      selectedItemBuilder: (context) {
        return groups.map((group) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group.name),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit(group);
                  } else if (value == 'delete' && !group.isDefault) {
                    onDelete(group);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!group.isDefault)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          );
        }).toList();
      },
    );
  }
}
