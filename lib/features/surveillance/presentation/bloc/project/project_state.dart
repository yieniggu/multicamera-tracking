import 'package:equatable/equatable.dart';
import '../../../domain/entities/project.dart';

abstract class ProjectState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProjectsInitial extends ProjectState {}

class ProjectsLoading extends ProjectState {}

class ProjectsLoaded extends ProjectState {
  final List<Project> projects;

  ProjectsLoaded(this.projects);

  @override
  List<Object?> get props => [projects];
}

class ProjectsError extends ProjectState {
  final String message;

  ProjectsError(this.message);

  @override
  List<Object?> get props => [message];
}
