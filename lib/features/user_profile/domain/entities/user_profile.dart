class UserProfile {
  final String uid;
  final String? email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String language;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });
}
