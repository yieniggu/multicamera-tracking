import 'package:multicamera_tracking/domain/entities/access_role.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String projectId;
  final Map<String, AccessRole> userRoles;
  final DateTime createdAt;
  final DateTime updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.projectId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });

  Group copyWith({
    String? name,
    String? description,
    Map<String, AccessRole>? userRoles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      projectId: projectId,
      userRoles: userRoles ?? this.userRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      projectId: json['projectId'] as String,
      userRoles: (json['userRoles'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, AccessRole.values.firstWhere((e) => e.name == v)),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'projectId': projectId,
        'userRoles': userRoles.map((k, v) => MapEntry(k, v.name)),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
