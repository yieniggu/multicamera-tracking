import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/camera_list.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/group_list.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/widgets/project_details/speed_dial_actions.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  int currentGroupIndex = 0;
  late final PageController _pageController;
  int _lastGroupCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectGroup(int index) {
    setState(() {
      currentGroupIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: BlocBuilder<GroupBloc, GroupState>(
        builder: (context, groupState) {
          final freshGroups = (groupState is GroupLoaded)
              ? groupState.getGroups(widget.project.id)
              : <Group>[];

          // Handle empty state
          if (freshGroups.isEmpty) {
            return const Center(
              child: Text("No groups found in this project."),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final isGroupAdded = freshGroups.length > _lastGroupCount;
            final isGroupDeleted = freshGroups.length < _lastGroupCount;
            _lastGroupCount = freshGroups.length;

            if (_pageController.hasClients) {
              if (isGroupAdded) {
                final newIndex = freshGroups.length - 1;
                _pageController.animateToPage(
                  newIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                if (currentGroupIndex != newIndex) {
                  setState(() => currentGroupIndex = newIndex);
                }
              } else if (isGroupDeleted) {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                if (currentGroupIndex != 0) {
                  setState(() => currentGroupIndex = 0);
                }
              } else {
                final safeIndex = currentGroupIndex.clamp(
                  0,
                  freshGroups.length - 1,
                );
                if (_pageController.page?.round() != safeIndex) {
                  _pageController.animateToPage(
                    safeIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              }
            }
          });

          final selectedGroup =
              freshGroups[currentGroupIndex.clamp(0, freshGroups.length - 1)];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.project.description),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 12, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Groups",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: GroupList(
                  projectId: widget.project.id,
                  currentGroupIndex: currentGroupIndex,
                  onPageChanged: _selectGroup,
                  pageController: _pageController,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12, left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Cameras in Selected Group",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: CameraList(
                  groupId: selectedGroup.id,
                  projectId: widget.project.id,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<GroupBloc, GroupState>(
        builder: (context, groupState) {
          final freshGroups = (groupState is GroupLoaded)
              ? groupState.getGroups(widget.project.id)
              : <Group>[];

          final selectedGroup = freshGroups.isNotEmpty
              ? freshGroups[currentGroupIndex.clamp(0, freshGroups.length - 1)]
              : null;

          return SpeedDialActions(
            project: widget.project,
            selectedGroup: selectedGroup,
          );
        },
      ),
    );
  }
}
