class GuestMigrationPlanValidationException implements Exception {
  final List<String> issues;

  const GuestMigrationPlanValidationException(this.issues);

  @override
  String toString() {
    if (issues.isEmpty) {
      return "GuestMigrationPlanValidationException";
    }
    return "GuestMigrationPlanValidationException(${issues.join(' | ')})";
  }
}
