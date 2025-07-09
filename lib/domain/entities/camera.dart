// domain/entities/camera.dart

enum AccessRole { admin, editor, viewer }

class Camera {
  final String id;
  final String name;
  final String description;
  final String rtspUrl;
  final String? thumbnailUrl;

  final String groupId;
  final Map<String, AccessRole> userRoles;

  // 🆕 New fields
  final DateTime createdAt;
  final DateTime updatedAt;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    required this.rtspUrl,
    this.thumbnailUrl,
    required this.groupId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });

  Camera copyWith({
    String? name,
    String? description,
    String? rtspUrl,
    String? thumbnailUrl,
    String? groupId,
    Map<String, AccessRole>? userRoles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Camera(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      groupId: groupId ?? this.groupId,
      userRoles: userRoles ?? this.userRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
