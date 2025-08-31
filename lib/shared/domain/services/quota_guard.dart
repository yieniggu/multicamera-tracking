abstract class QuotaGuard {
  Future<void> ensureCanCreateProject();
  Future<void> ensureCanCreateGroup(String projectId);
  Future<void> ensureCanCreateCamera(String projectId, String groupId);
}
