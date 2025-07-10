import 'package:multicamera_tracking/domain/entities/access_role.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final bool isDefault;
  final Map<String, AccessRole> userRoles;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.isDefault,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({
    String? name,
    String? description,
    bool? isDefault,
    Map<String, AccessRole>? userRoles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      description: description ?? this.description,
      userRoles: userRoles ?? this.userRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool,
      description: json['description'] as String,
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
    'isDefault': isDefault,
    'description': description,
    'userRoles': userRoles.map((k, v) => MapEntry(k, v.name)),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
