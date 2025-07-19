import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_camera_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_group_sheet.dart';

class SpeedDialActions extends StatelessWidget {
  final Project project;
  final Group? selectedGroup;

  const SpeedDialActions({
    super.key,
    required this.project,
    required this.selectedGroup,
  });

  void _createGroup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddGroupSheet(projectId: project.id),
    );
  }

  void _createCamera(BuildContext context) {
    if (selectedGroup == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AddCameraSheet(initialProject: project, initialGroup: selectedGroup),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      overlayOpacity: 0.1,
      spacing: 10,
      spaceBetweenChildren: 8,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.group_add),
          label: 'Add Group',
          onTap: () => _createGroup(context),
        ),
        if (selectedGroup != null)
          SpeedDialChild(
            child: const Icon(Icons.videocam),
            label: 'Add Camera',
            onTap: () => _createCamera(context),
          ),
      ],
    );
  }
}
