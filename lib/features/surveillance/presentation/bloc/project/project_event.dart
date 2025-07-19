import 'package:equatable/equatable.dart';
import '../../../domain/entities/project.dart';

abstract class ProjectEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectEvent {}

class AddOrUpdateProject extends ProjectEvent {
  final Project project;

  AddOrUpdateProject(this.project);

  @override
  List<Object?> get props => [project];
}

class DeleteProject extends ProjectEvent {
  final String projectId;

  DeleteProject(this.projectId);

  @override
  List<Object?> get props => [projectId];
}
