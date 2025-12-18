import 'package:equatable/equatable.dart';
import '../../../domain/entities/group.dart';

abstract class GroupState extends Equatable {
  const GroupState();

  @override
  List<Object?> get props => [];
}

class GroupInitial extends GroupState {
  const GroupInitial();
}

class GroupLoaded extends GroupState {
  final Map<String, List<Group>> grouped;
  final Set<String> savingGroupIds;
  final Set<String> loadingProjectIds;

  const GroupLoaded({
    required this.grouped,
    this.savingGroupIds = const {},
    this.loadingProjectIds = const {},
  });

  GroupLoaded copyWith({
    Map<String, List<Group>>? grouped,
    Set<String>? savingGroupIds,
    Set<String>? loadingProjectIds,
  }) {
    return GroupLoaded(
      grouped: grouped ?? this.grouped,
      savingGroupIds: savingGroupIds ?? this.savingGroupIds,
      loadingProjectIds: loadingProjectIds ?? this.loadingProjectIds,
    );
  }

  List<Group> getGroups(String projectId) => grouped[projectId] ?? const [];

  bool isSaving(String groupId) => savingGroupIds.contains(groupId);

  bool isLoadingProject(String projectId) =>
      loadingProjectIds.contains(projectId);

  @override
  List<Object?> get props => [grouped, savingGroupIds, loadingProjectIds];
}

class GroupError extends GroupState {
  final String message;
  const GroupError(this.message);

  @override
  List<Object?> get props => [message];
}
