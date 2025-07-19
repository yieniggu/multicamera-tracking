import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/delete_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/get_all_projects.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/save_project.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final GetAllProjectsUseCase getAllProjectsUseCase;
  final SaveProjectUseCase saveProjectUseCase;
  final DeleteProjectUseCase deleteProjectUseCase;

  ProjectBloc({
    required this.getAllProjectsUseCase,
    required this.saveProjectUseCase,
    required this.deleteProjectUseCase,
  }) : super(ProjectsInitial()) {
    on<LoadProjects>(_onLoadAllProjects);
    on<AddOrUpdateProject>(_onSave);
    on<DeleteProject>(_onDelete);
  }

  // State emitter for loading all projects
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
      add(LoadProjects()); // Reload after save
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
      add(LoadProjects()); // Reload after delete
    } catch (e) {
      emit(ProjectsError(e.toString()));
    }
  }
}
