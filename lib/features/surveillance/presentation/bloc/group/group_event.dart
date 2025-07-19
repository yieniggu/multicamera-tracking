import 'package:equatable/equatable.dart';
import '../../../domain/entities/group.dart';

abstract class GroupEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class LoadGroupsByProject extends GroupEvent {
  final String projectId;

  LoadGroupsByProject(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

final class AddOrUpdateGroup extends GroupEvent {
  final Group group;

  AddOrUpdateGroup(this.group);

  @override
  List<Object?> get props => [group];
}

final class DeleteGroup extends GroupEvent {
  final Group group;

  DeleteGroup(this.group);

  @override
  List<Object?> get props => [group];
}

/// Event to mark a camera as saving (e.g. while persisting).
final class MarkGroupSaving extends GroupEvent {
  final String groupId;

  MarkGroupSaving(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Event to unmark a camera as saving (after completion).
class UnmarkGroupSaving extends GroupEvent {
  final String groupId;
  final String projectId;

  UnmarkGroupSaving(this.groupId, this.projectId);

  @override
  List<Object?> get props => [groupId];
}
