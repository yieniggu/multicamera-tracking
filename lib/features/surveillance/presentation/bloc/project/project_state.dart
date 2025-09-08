import 'package:equatable/equatable.dart';
import '../../../domain/entities/project.dart';

abstract class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

class ProjectsInitial extends ProjectState {}

class ProjectsLoading extends ProjectState {}

class ProjectsLoaded extends ProjectState {
  final List<Project> projects;
  final Set<String> savingProjectIds;

  const ProjectsLoaded(this.projects, {this.savingProjectIds = const {}});

  ProjectsLoaded copyWith({
    List<Project>? projects,
    Set<String>? savingProjectIds,
  }) {
    return ProjectsLoaded(
      projects ?? this.projects,
      savingProjectIds: savingProjectIds ?? this.savingProjectIds,
    );
  }

  bool isSaving(String projectId) => savingProjectIds.contains(projectId);

  @override
  List<Object?> get props => [projects, savingProjectIds];
}

class ProjectsError extends ProjectState {
  final String message;

  ProjectsError(this.message);

  @override
  List<Object?> get props => [message];
}
