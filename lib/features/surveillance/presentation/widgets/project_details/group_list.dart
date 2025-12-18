import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_group_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/group_card.dart';

class GroupList extends StatelessWidget {
  final int currentGroupIndex;
  final Function(int) onPageChanged;
  final PageController pageController;
  final String projectId;

  const GroupList({
    super.key,
    required this.projectId,
    required this.currentGroupIndex,
    required this.onPageChanged,
    required this.pageController,
  });

  void _editGroup(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddGroupSheet(existingGroup: group, projectId: projectId),
    );
  }

  Future<void> _deleteGroup(BuildContext context, Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Group"),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<GroupBloc>().add(DeleteGroup(group));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupBloc, GroupState>(
      builder: (context, groupState) {
        if (groupState is GroupError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Error loading groups:\n${groupState.message}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (groupState is! GroupLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = groupState.getGroups(projectId);
        final isLoadingThisProject = groupState.isLoadingProject(projectId);

        debugPrint(
          '[GROUP-LIST] groups for $projectId: ${groups.map((g) => g.name).join(', ')}',
        );

        if (groups.isEmpty) {
          if (isLoadingThisProject) {
            return const Center(child: CircularProgressIndicator());
          }

          return const Center(
            child: Text(
              "No groups in this project.\nTap the '+' button to add one!",
              textAlign: TextAlign.center,
            ),
          );
        }

        return PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final group = groups[i];
            final isSaving = groupState.isSaving(group.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Opacity(
                opacity: isSaving ? 0.5 : 1.0,
                child: Column(
                  children: [
                    Expanded(
                      child: GroupCard(
                        key: ValueKey(group.id),
                        group: group,
                        onEdit: isSaving
                            ? null
                            : () => _editGroup(context, group),
                        onDelete: isSaving
                            ? null
                            : () => _deleteGroup(context, group),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
