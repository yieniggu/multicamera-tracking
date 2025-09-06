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
      emit(ProjectsLoaded(projects));
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }

  Future<void> _onSave(
    AddOrUpdateProject event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await saveProjectUseCase(event.project);
      // repo will emit ProjectUpserted; no reload
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteProject event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await deleteProjectUseCase(event.projectId);
      // repo will emit ProjectDeleted; no reload
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
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
      emit(ProjectsLoaded(list));
    } else if (e is ProjectDeleted) {
      final list = curr.projects.where((p) => p.id != e.projectId).toList();
      emit(ProjectsLoaded(list));
    }
  }
}
