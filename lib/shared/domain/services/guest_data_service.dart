abstract class GuestDataService {
  Future<bool> hasDataToMigrate({String? sourceUserId});
  Future<String?> resolveMigrationSourceUserId({String? preferredSourceUserId});
  Future<bool> adoptLocalDataForUser({
    required String targetUserId,
    String? preferredSourceUserId,
  });
  Future<void> clearLocalData();
}
