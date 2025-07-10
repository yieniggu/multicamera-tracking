import 'package:multicamera_tracking/domain/entities/access_role.dart';

class Camera {
  final String id;
  final String name;
  final String description;
  final String rtspUrl;
  final String? thumbnailUrl;
  final String projectId;
  final String groupId;
  final Map<String, AccessRole> userRoles;
  final DateTime createdAt;
  final DateTime updatedAt;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    required this.rtspUrl,
    this.thumbnailUrl,
    required this.projectId,
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
    String? projectId,
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
      projectId: projectId ?? this.projectId,
      groupId: groupId ?? this.groupId,
      userRoles: userRoles ?? this.userRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      rtspUrl: json['rtspUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      projectId: json['projectId'] as String,
      groupId: json['groupId'] as String,
      userRoles: (json['userRoles'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, AccessRole.values.byName(value)),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rtspUrl': rtspUrl,
      'thumbnailUrl': thumbnailUrl,
      'projectId': projectId,
      'groupId': groupId,
      'userRoles': userRoles.map((key, value) => MapEntry(key, value.name)),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
