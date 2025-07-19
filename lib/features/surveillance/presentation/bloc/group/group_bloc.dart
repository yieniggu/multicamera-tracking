import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/delete_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/get_all_groups_by_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/save_group.dart';

import 'group_event.dart';
import 'group_state.dart';

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GetAllGroupsByProjectUseCase getAllGroupsByProjectUseCase;
  final SaveGroupUseCase saveGroupUseCase;
  final DeleteGroupUseCase deleteGroupUseCase;

  GroupBloc({
    required this.getAllGroupsByProjectUseCase,
    required this.saveGroupUseCase,
    required this.deleteGroupUseCase,
  }) : super(const GroupInitial()) {
    on<LoadGroupsByProject>(_onLoadGroupsByProject);
    on<AddOrUpdateGroup>(_onAddOrUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
    on<MarkGroupSaving>(_onMarkGroupSaving);
    on<UnmarkGroupSaving>(_onUnmarkGroupSaving);
  }

  Future<void> _onLoadGroupsByProject(
    LoadGroupsByProject event,
    Emitter<GroupState> emit,
  ) async {
    try {
      debugPrint("🔄 Loading groups for project: ${event.projectId}");
      final groups = await getAllGroupsByProjectUseCase(event.projectId);
      debugPrint("✅ Groups loaded: ${groups.map((g) => g.name).join(', ')}");

      final grouped = <String, List<Group>>{};

      // Deep clone all current grouped data except the updated project
      if (state is GroupLoaded) {
        final currentGrouped = (state as GroupLoaded).grouped;
        for (final entry in currentGrouped.entries) {
          grouped[entry.key] = List<Group>.from(entry.value);
        }
      }

      // ⚠️ Force full replacement for the updated project
      grouped[event.projectId] = List<Group>.from(groups);

      final savingGroupIds = (state is GroupLoaded)
          ? (state as GroupLoaded).savingGroupIds.intersection(
              groups.map((g) => g.id).toSet(),
            )
          : <String>{};

      debugPrint(
        '[BLOC] Emitting GroupLoaded with: ${grouped[event.projectId]?.map((g) => g.name).join(', ')}',
      );

      debugPrint(
        '[BLOC] Final group names emitted for ${event.projectId}: ${groups.map((g) => g.name).join(', ')}',
      );

      emit(GroupLoaded(grouped: grouped, savingGroupIds: savingGroupIds));
    } catch (e) {
      debugPrint("❌ Failed to load groups: $e");
      emit(
        GroupError("Failed to load groups for project ${event.projectId}: $e"),
      );
    }
  }

  Future<void> _onAddOrUpdateGroup(
    AddOrUpdateGroup event,
    Emitter<GroupState> emit,
  ) async {
    final group = event.group;
    debugPrint("💾 Saving group: ${group.name} (${group.id})");

    add(MarkGroupSaving(group.id));

    try {
      await saveGroupUseCase(group);
      debugPrint("✅ Group saved: ${group.name}");

      // 👇 Ensure fresh reload after saving
      add(LoadGroupsByProject(group.projectId));
    } catch (e) {
      debugPrint("❌ Failed to save group: $e");
      emit(GroupError("Failed to save group: $e"));
    } finally {
      add(UnmarkGroupSaving(group.id, group.projectId));
    }
  }

  Future<void> _onDeleteGroup(
    DeleteGroup event,
    Emitter<GroupState> emit,
  ) async {
    final group = event.group;
    debugPrint("🗑️ Deleting group: ${group.name} (${group.id})");

    add(MarkGroupSaving(group.id));

    try {
      await deleteGroupUseCase(group.projectId, group.id);
      debugPrint("✅ Group deleted: ${group.name}");
      add(LoadGroupsByProject(group.projectId));
    } catch (e) {
      debugPrint("❌ Failed to delete group: $e");
      emit(GroupError("Failed to delete group: $e"));
    } finally {
      add(UnmarkGroupSaving(group.id, group.projectId));
    }
  }

  void _onMarkGroupSaving(MarkGroupSaving event, Emitter<GroupState> emit) {
    final current = state;
    if (current is! GroupLoaded) return;

    final updatedSet = {...current.savingGroupIds, event.groupId};
    debugPrint("⏳ Marking group saving: ${event.groupId}");
    emit(current.copyWith(savingGroupIds: updatedSet));
  }

  void _onUnmarkGroupSaving(
    UnmarkGroupSaving event,
    Emitter<GroupState> emit,
  ) async {
    final current = state;
    if (current is! GroupLoaded) return;

    final projectId = event.projectId;

    debugPrint("✅ Unmarking group saving: ${event.groupId}");

    try {
      final groups = await getAllGroupsByProjectUseCase(projectId);
      debugPrint(
        "✅ Groups reloaded after save: ${groups.map((g) => g.name).join(', ')}",
      );

      final grouped = Map<String, List<Group>>.from(current.grouped);
      grouped[projectId] = groups;

      final updatedSavingIds = Set<String>.from(current.savingGroupIds)
        ..remove(event.groupId);

      emit(GroupLoaded(grouped: grouped, savingGroupIds: updatedSavingIds));
    } catch (e) {
      debugPrint("❌ Failed to reload groups during unmark: $e");
      emit(GroupError("Failed to reload groups: $e"));
    }
  }
}

String? _findProjectIdForGroup(
  String groupId,
  Map<String, List<Group>> grouped,
) {
  for (final entry in grouped.entries) {
    if (entry.value.any((g) => g.id == groupId)) return entry.key;
  }
  return null;
}
