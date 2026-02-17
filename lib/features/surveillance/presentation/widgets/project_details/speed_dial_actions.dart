import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_camera_sheet.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/add_group_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/shared/constants/quota.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_state.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/config/di.dart';

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
    final trial = getIt<AppMode>().isTrial;

    // group count in this project
    final groupState = context.watch<GroupBloc>().state;
    final groups = (groupState is GroupLoaded)
        ? groupState.getGroups(project.id)
        : <Group>[];
    final groupCount = groups.length;

    // camera count in selected group (if any)
    final cameraState = context.watch<CameraBloc>().state;
    final camCount = (selectedGroup != null && cameraState is CameraLoaded)
        ? cameraState.getCameras(project.id, selectedGroup!.id).length
        : 0;

    final canAddGroup = !trial || groupCount < Quota.groupsPerProject;
    final canAddCamera =
        selectedGroup != null && (!trial || camCount < Quota.camerasPerGroup);

    void _explain(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

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
          label: trial
              ? 'Add Group ($groupCount/${Quota.groupsPerProject})'
              : 'Add Group',
          onTap: canAddGroup
              ? () => _createGroup(context)
              : () => _explain(
                  "Trial limit: only ${Quota.groupsPerProject} group per project in guest mode.",
                ),
        ),
        if (selectedGroup != null)
          SpeedDialChild(
            child: const Icon(Icons.videocam),
            label: trial
                ? 'Add Camera ($camCount/${Quota.camerasPerGroup})'
                : 'Add Camera',
            onTap: canAddCamera
                ? () => _createCamera(context)
                : () => _explain(
                    "Trial limit: max ${Quota.camerasPerGroup} cameras per group in guest mode.",
                  ),
          ),
      ],
    );
  }
}
