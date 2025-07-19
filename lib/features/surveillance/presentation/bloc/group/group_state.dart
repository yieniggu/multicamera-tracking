import 'package:equatable/equatable.dart';
import '../../../domain/entities/group.dart';

/// Abstract base class for all group states in the BLoC.
abstract class GroupState extends Equatable {
  const GroupState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any groups are loaded.
class GroupInitial extends GroupState {
  const GroupInitial();
}

/// State representing an ongoing group loading process.
class GroupLoading extends GroupState {
  const GroupLoading();
}

/// Loaded state containing all groups and saving indicators.
class GroupLoaded extends GroupState {
  /// Structure: projectId → list of groups
  final Map<String, List<Group>> grouped;

  /// IDs of groups currently being added or updated.
  final Set<String> savingGroupIds;

  const GroupLoaded({required this.grouped, this.savingGroupIds = const {}});

  /// Creates a new state with optional overrides.
  GroupLoaded copyWith({
    Map<String, List<Group>>? grouped,
    Set<String>? savingGroupIds,
  }) {
    return GroupLoaded(
      grouped: grouped ?? this.grouped,
      savingGroupIds: savingGroupIds ?? this.savingGroupIds,
    );
  }

  /// Returns the list of groups for a given project.
  List<Group> getGroups(String projectId) {
    return grouped[projectId] ?? [];
  }

  /// Returns whether a specific group is being saved.
  bool isSaving(String groupId) {
    return savingGroupIds.contains(groupId);
  }

  @override
  List<Object?> get props => [grouped, savingGroupIds];
}

/// State representing an error while loading or modifying groups.
class GroupError extends GroupState {
  final String message;

  const GroupError(this.message);

  @override
  List<Object?> get props => [message];
}
