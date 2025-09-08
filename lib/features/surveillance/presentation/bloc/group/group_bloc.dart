import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/delete_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/get_all_groups_by_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/save_group.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';

import 'group_event.dart';
import 'group_state.dart';

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GetAllGroupsByProjectUseCase getAllGroupsByProjectUseCase;
  final SaveGroupUseCase saveGroupUseCase;
  final DeleteGroupUseCase deleteGroupUseCase;
  final SurveillanceEventBus bus;

  late final StreamSubscription _busSub;

  GroupBloc({
    required this.getAllGroupsByProjectUseCase,
    required this.saveGroupUseCase,
    required this.deleteGroupUseCase,
    required this.bus,
  }) : super(const GroupInitial()) {
    on<LoadGroupsByProject>(_onLoadGroupsByProject);
    on<AddOrUpdateGroup>(_onAddOrUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
    on<MarkGroupSaving>(_onMarkGroupSaving);
    on<UnmarkGroupSaving>(_onUnmarkGroupSaving);

    _busSub = bus.stream.listen((e) {
      debugPrint('[BUS→GroupBloc] bus=${bus.id} event=${e.runtimeType}');
      _onBusEvent(e);
    });
  }

  @override
  Future<void> close() async {
    await _busSub.cancel();
    return super.close();
  }

  Future<void> _onLoadGroupsByProject(
    LoadGroupsByProject event,
    Emitter<GroupState> emit,
  ) async {
    emit(const GroupLoading());
    try {
      final groups = await getAllGroupsByProjectUseCase(event.projectId);

      final grouped = <String, List<Group>>{};
      if (state is GroupLoaded) {
        final current = (state as GroupLoaded).grouped;
        for (final e in current.entries) {
          grouped[e.key] = List<Group>.from(e.value);
        }
      }
      grouped[event.projectId] = List<Group>.from(groups);

      final savingIds = state is GroupLoaded
          ? (state as GroupLoaded).savingGroupIds
          : <String>{};

      emit(GroupLoaded(grouped: grouped, savingGroupIds: savingIds));
    } catch (e) {
      emit(
        GroupError("Failed to load groups for project ${event.projectId}: $e"),
      );
    }
  }

  Future<void> _onAddOrUpdateGroup(
    AddOrUpdateGroup event,
    Emitter<GroupState> emit,
  ) async {
    add(MarkGroupSaving(event.group.id));
    try {
      await saveGroupUseCase(event.group);

      // Optimistically update UI without waiting for the bus
      final curr = state;
      if (curr is GroupLoaded) {
        final grouped = Map<String, List<Group>>.from(curr.grouped);
        final list = List<Group>.from(
          grouped[event.group.projectId] ?? const [],
        );
        final idx = list.indexWhere((g) => g.id == event.group.id);
        if (idx >= 0) {
          list[idx] = event.group;
        } else {
          list.add(event.group);
        }
        grouped[event.group.projectId] = list;
        emit(curr.copyWith(grouped: grouped));
      }
    } catch (e) {
      emit(GroupError("Failed to save group: $e"));
    } finally {
      add(UnmarkGroupSaving(event.group.id, event.group.projectId));
    }
  }

  Future<void> _onDeleteGroup(
    DeleteGroup event,
    Emitter<GroupState> emit,
  ) async {
    add(MarkGroupSaving(event.group.id));
    try {
      await deleteGroupUseCase(event.group.projectId, event.group.id);
      // repo will emit GroupDeleted; no reload
    } catch (e) {
      emit(GroupError("Failed to delete group: $e"));
    } finally {
      add(UnmarkGroupSaving(event.group.id, event.group.projectId));
    }
  }

  void _onMarkGroupSaving(MarkGroupSaving event, Emitter<GroupState> emit) {
    final current = state;
    if (current is! GroupLoaded) return;
    emit(
      current.copyWith(
        savingGroupIds: {...current.savingGroupIds, event.groupId},
      ),
    );
  }

  void _onUnmarkGroupSaving(UnmarkGroupSaving event, Emitter<GroupState> emit) {
    final current = state;
    if (current is! GroupLoaded) return;
    final updated = Set<String>.from(current.savingGroupIds)
      ..remove(event.groupId);
    emit(current.copyWith(savingGroupIds: updated));
  }

  void _onBusEvent(SurveillanceEvent e) {
    final current = state;

    final grouped = current is GroupLoaded
        ? Map<String, List<Group>>.from(current.grouped)
        : <String, List<Group>>{};

    final saving = current is GroupLoaded ? current.savingGroupIds : <String>{};

    if (e is GroupUpserted) {
      final p = e.group.projectId;
      final list = List<Group>.from(grouped[p] ?? const []);
      final idx = list.indexWhere((g) => g.id == e.group.id);
      if (idx >= 0) {
        list[idx] = e.group;
      } else {
        list.add(e.group);
      }
      grouped[p] = list;

      emit(GroupLoaded(grouped: grouped, savingGroupIds: saving));
    } else if (e is GroupDeleted) {
      final p = e.projectId;
      final list = List<Group>.from(grouped[p] ?? const []);
      grouped[p] = list.where((g) => g.id != e.groupId).toList();

      emit(GroupLoaded(grouped: grouped, savingGroupIds: saving));
    }
  }
}
