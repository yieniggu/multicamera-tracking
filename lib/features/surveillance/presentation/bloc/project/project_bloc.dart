import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/delete_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/get_all_projects.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/save_project.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';

import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final GetAllProjectsUseCase getAllProjectsUseCase;
  final SaveProjectUseCase saveProjectUseCase;
  final DeleteProjectUseCase deleteProjectUseCase;
  final SurveillanceEventBus bus;

  late final StreamSubscription _busSub;

  ProjectBloc({
    required this.getAllProjectsUseCase,
    required this.saveProjectUseCase,
    required this.deleteProjectUseCase,
    required this.bus,
  }) : super(ProjectsInitial()) {
    on<LoadProjects>(_onLoadAllProjects);
    on<AddOrUpdateProject>(_onSave);
    on<DeleteProject>(_onDelete);
    on<MarkProjectSaving>(_onMarkSaving);
    on<UnmarkProjectSaving>(_onUnmarkSaving);
    on<ResetProjects>(_onReset);

    _busSub = bus.stream.listen(_onBusEvent);
  }

  @override
  Future<void> close() async {
    await _busSub.cancel();
    return super.close();
  }

  Future<void> _onLoadAllProjects(
    LoadProjects event,
    Emitter<ProjectState> emit,
  ) async {
    emit(ProjectsLoading());
    try {
      final projects = await getAllProjectsUseCase();
      final prevSaving = state is ProjectsLoaded
          ? (state as ProjectsLoaded).savingProjectIds
          : <String>{};
      emit(ProjectsLoaded(projects, savingProjectIds: prevSaving));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }

  Future<void> _onSave(
    AddOrUpdateProject event,
    Emitter<ProjectState> emit,
  ) async {
    add(MarkProjectSaving(event.project.id));
    try {
      await saveProjectUseCase(event.project);
      // event bus will notify; no manual reload here
    } catch (e) {
      emit(ProjectsError(e.toString()));
    } finally {
      add(UnmarkProjectSaving(event.project.id));
    }
  }

  Future<void> _onDelete(
    DeleteProject event,
    Emitter<ProjectState> emit,
  ) async {
    add(MarkProjectSaving(event.projectId));
    try {
      await deleteProjectUseCase(event.projectId);
      // event bus will notify; no manual reload here
    } catch (e) {
      emit(ProjectsError(e.toString()));
    } finally {
      add(UnmarkProjectSaving(event.projectId));
    }
  }

  void _onMarkSaving(MarkProjectSaving event, Emitter<ProjectState> emit) {
    final curr = state;
    if (curr is! ProjectsLoaded) return;
    final updated = {...curr.savingProjectIds, event.projectId};
    emit(curr.copyWith(savingProjectIds: updated));
  }

  void _onUnmarkSaving(UnmarkProjectSaving event, Emitter<ProjectState> emit) {
    final curr = state;
    if (curr is! ProjectsLoaded) return;
    final updated = Set<String>.from(curr.savingProjectIds)
      ..remove(event.projectId);
    emit(curr.copyWith(savingProjectIds: updated));
  }

  void _onReset(ResetProjects event, Emitter<ProjectState> emit) {
    emit(ProjectsInitial());
  }

  void _onBusEvent(SurveillanceEvent e) {
    final curr = state;
    if (curr is! ProjectsLoaded) return;

    if (e is ProjectUpserted) {
      final list = [...curr.projects];
      final idx = list.indexWhere((p) => p.id == e.project.id);
      if (idx >= 0) {
        list[idx] = e.project;
      } else {
        list.add(e.project);
      }
      emit(curr.copyWith(projects: list));
    } else if (e is ProjectDeleted) {
      final list = curr.projects.where((p) => p.id != e.projectId).toList();
      final saving = Set<String>.from(curr.savingProjectIds)
        ..remove(e.projectId);
      emit(curr.copyWith(projects: list, savingProjectIds: saving));
    }
  }
}
