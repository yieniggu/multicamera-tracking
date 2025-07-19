import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';

class SaveGroupUseCase {
  final GroupRepository repo;
  SaveGroupUseCase(this.repo);

  Future<void> call(Group group) {
    final updatedGroup = group.copyWith(updatedAt: DateTime.now());
    return repo.save(updatedGroup);
  }
}
