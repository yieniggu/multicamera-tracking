import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';

class SaveProjectUseCase {
  final ProjectRepository repo;
  final QuotaGuard quota;
  SaveProjectUseCase(this.repo, this.quota);
  Future<void> call(Project project) async {
    await quota.ensureCanCreateProject();
    await repo.save(project);
  }
}
