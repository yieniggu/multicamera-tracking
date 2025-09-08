import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';

class SaveGroupUseCase {
  final GroupRepository repo;
  final QuotaGuard quota;
  SaveGroupUseCase(this.repo, this.quota);

  Future<void> call(Group group) async {
    final existing = await repo.getAllByProject(group.projectId);
    final isCreating = !existing.any((g) => g.id == group.id);
    if (isCreating) {
      await quota.ensureCanCreateGroup(group.projectId);
    }
    final updated = group.copyWith(updatedAt: DateTime.now());
    await repo.save(updated);
  }
}
