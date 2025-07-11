import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';

import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/presentation/screens/camera_player_screen.dart';
import 'package:multicamera_tracking/presentation/widgets/home/add_camera_sheet.dart';
import 'package:multicamera_tracking/presentation/widgets/home/add_group_sheet.dart';
import 'package:multicamera_tracking/presentation/widgets/home/camera_card.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  Group? selectedGroup;
  int currentGroupIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);

    // Defer provider access until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<ProjectManager>();
      final groups = manager.groupsInProject(widget.project.id);
      if (groups.isNotEmpty) {
        setState(() {
          selectedGroup = groups.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectGroup(int index) {
    final manager = context.read<ProjectManager>();
    final groups = manager.groupsInProject(widget.project.id);
    setState(() {
      currentGroupIndex = index;
      selectedGroup = groups[index];
    });
  }

  void _openCamera(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraPlayerScreen(camera: camera)),
    );
  }

  void _editCamera(Camera camera) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectManager>(),
        child: AddCameraSheet(existingCamera: camera),
      ),
    );
  }

  Future<void> _deleteCamera(Camera camera) async {
    final manager = context.read<ProjectManager>();
    await manager.deleteCamera(camera);
    setState(() {});
  }

  Future<void> _editGroup(Group group) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectManager>(),
        child: AddGroupSheet(
          existingGroup: group,
          projectId: widget.project.id,
        ),
      ),
    );

    // Now that the modal is closed, refresh selectedGroup
    final manager = context.read<ProjectManager>();
    final updatedGroups = manager.groupsInProject(widget.project.id);

    final updatedGroup = updatedGroups.firstWhere(
      (g) => g.id == group.id,
      orElse: () => group,
    );

    setState(() {
      selectedGroup = updatedGroup;
    });
  }

  Future<void> _deleteGroup(Group group) async {
    final manager = context.read<ProjectManager>();

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
      await manager.deleteGroup(group);
      final remaining = manager.groupsInProject(widget.project.id);
      setState(() {
        selectedGroup = remaining.firstOrNull;
        currentGroupIndex = 0;
      });
      if (remaining.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              currentGroupIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  void _createGroup() async {
    final initialGroupCount = context
        .read<ProjectManager>()
        .groupsInProject(widget.project.id)
        .length;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectManager>(),
        child: AddGroupSheet(projectId: widget.project.id),
      ),
    );

    final updatedGroups = context.read<ProjectManager>().groupsInProject(
      widget.project.id,
    );
    if (updatedGroups.length > initialGroupCount) {
      final newGroup = updatedGroups.last;
      setState(() {
        currentGroupIndex = updatedGroups.indexOf(newGroup);
        selectedGroup = newGroup;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            currentGroupIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _createCamera() {
    if (selectedGroup == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectManager>(),
        child: AddCameraSheet(
          initialProject: widget.project,
          initialGroup: selectedGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProjectManager>();
    final groups = manager.groupsInProject(widget.project.id);
    final cameras = selectedGroup != null
        ? manager.camerasInGroup(widget.project.id, selectedGroup!.id)
        : [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: groups.isEmpty
          ? const Center(child: Text("No groups found in this project."))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(widget.project.description),
                ),
                SizedBox(
                  height: 170,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _selectGroup,
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final group = groups[i];
                      final camCount = manager.cameraCount(
                        group.projectId,
                        group.id,
                      );

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(group.description),
                              const SizedBox(height: 8),
                              Text("Users: ${group.userRoles.length}"),
                              Text("Cameras: $camCount"),
                              const Spacer(),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text("Edit"),
                                    onPressed: () => _editGroup(group),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!group.isDefault)
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text("Delete"),
                                      onPressed: () => _deleteGroup(group),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                  child: cameras.isEmpty
                      ? const Center(child: Text("No cameras found."))
                      : ListView.builder(
                          itemCount: cameras.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (_, i) {
                            final cam = cameras[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: CameraCard(
                                camera: cam,
                                onTap: () => _openCamera(cam),
                                onEdit: () => _editCamera(cam),
                                onDelete: () => _deleteCamera(cam),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: SpeedDial(
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
            onTap: _createGroup,
          ),
          if (selectedGroup != null)
            SpeedDialChild(
              child: const Icon(Icons.videocam),
              label: 'Add Camera',
              onTap: _createCamera,
            ),
        ],
      ),
    );
  }
}
