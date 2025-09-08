import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';

class SaveProjectUseCase {
  final ProjectRepository repo;
  final QuotaGuard quota;
  SaveProjectUseCase(this.repo, this.quota);

  Future<void> call(Project project) async {
    // Only enforce quota if this is a *new* project
    final existing = await repo.getAll();
    final isEditing = existing.any((p) => p.id == project.id);
    if (!isEditing) {
      await quota.ensureCanCreateProject();
    }
    await repo.save(project);
  }
}
