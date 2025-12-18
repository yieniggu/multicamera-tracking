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

  // Internal cache prevents dropping previously loaded projects
  final Map<String, List<Group>> _groupedCache = {};

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

  GroupLoaded _asLoadedStateOrInit() {
    final s = state;
    if (s is GroupLoaded) return s;

    return GroupLoaded(
      grouped: _cloneGrouped(_groupedCache),
      savingGroupIds: const {},
      loadingProjectIds: const {},
    );
  }

  Future<void> _onLoadGroupsByProject(
    LoadGroupsByProject event,
    Emitter<GroupState> emit,
  ) async {
    final curr = _asLoadedStateOrInit();

    emit(
      curr.copyWith(
        loadingProjectIds: {...curr.loadingProjectIds, event.projectId},
      ),
    );

    try {
      final groups = await getAllGroupsByProjectUseCase(event.projectId);

      _groupedCache[event.projectId] = List<Group>.from(groups);

      final nextLoading = Set<String>.from(curr.loadingProjectIds)
        ..remove(event.projectId);

      emit(
        curr.copyWith(
          grouped: _cloneGrouped(_groupedCache),
          loadingProjectIds: nextLoading,
        ),
      );
    } catch (e) {
      final nextLoading = Set<String>.from(curr.loadingProjectIds)
        ..remove(event.projectId);

      // Keep whatever we had, just clear the loading bit for that project
      emit(
        curr.copyWith(
          grouped: _cloneGrouped(_groupedCache),
          loadingProjectIds: nextLoading,
        ),
      );
      debugPrint(
        '[GroupBloc] Failed to load groups for project ${event.projectId}: $e',
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

      final curr = _asLoadedStateOrInit();
      final p = event.group.projectId;

      final list = List<Group>.from(_groupedCache[p] ?? const []);
      final idx = list.indexWhere((g) => g.id == event.group.id);
      if (idx >= 0) {
        list[idx] = event.group;
      } else {
        list.add(event.group);
      }
      _groupedCache[p] = list;

      emit(curr.copyWith(grouped: _cloneGrouped(_groupedCache)));
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

      final p = event.group.projectId;
      final list = List<Group>.from(_groupedCache[p] ?? const []);
      _groupedCache[p] = list.where((g) => g.id != event.group.id).toList();

      final curr = _asLoadedStateOrInit();
      emit(curr.copyWith(grouped: _cloneGrouped(_groupedCache)));
    } catch (e) {
      emit(GroupError("Failed to delete group: $e"));
    } finally {
      add(UnmarkGroupSaving(event.group.id, event.group.projectId));
    }
  }

  void _onMarkGroupSaving(MarkGroupSaving event, Emitter<GroupState> emit) {
    final curr = _asLoadedStateOrInit();
    emit(
      curr.copyWith(savingGroupIds: {...curr.savingGroupIds, event.groupId}),
    );
  }

  void _onUnmarkGroupSaving(UnmarkGroupSaving event, Emitter<GroupState> emit) {
    final curr = _asLoadedStateOrInit();
    final updated = Set<String>.from(curr.savingGroupIds)
      ..remove(event.groupId);
    emit(curr.copyWith(savingGroupIds: updated));
  }

  void _onBusEvent(SurveillanceEvent e) {
    final curr = _asLoadedStateOrInit();

    if (e is GroupUpserted) {
      final p = e.group.projectId;
      final list = List<Group>.from(_groupedCache[p] ?? const []);
      final idx = list.indexWhere((g) => g.id == e.group.id);
      if (idx >= 0) {
        list[idx] = e.group;
      } else {
        list.add(e.group);
      }
      _groupedCache[p] = list;

      emit(curr.copyWith(grouped: _cloneGrouped(_groupedCache)));
      return;
    }

    if (e is GroupDeleted) {
      final p = e.projectId;
      final list = List<Group>.from(_groupedCache[p] ?? const []);
      _groupedCache[p] = list.where((g) => g.id != e.groupId).toList();

      emit(curr.copyWith(grouped: _cloneGrouped(_groupedCache)));
      return;
    }
  }

  Map<String, List<Group>> _cloneGrouped(Map<String, List<Group>> original) {
    return original.map((k, v) => MapEntry(k, List<Group>.from(v)));
  }
}
