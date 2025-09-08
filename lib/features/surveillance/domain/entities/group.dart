import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/shared/utils/role_parse.dart';

class Group extends Equatable {
  final String id;
  final String name;
  final bool isDefault;
  final String description;
  final String projectId;
  final Map<String, AccessRole> userRoles;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.description,
    required this.projectId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });

  Group copyWith({
    String? name,
    String? description,
    bool? isDefault,
    Map<String, AccessRole>? userRoles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
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
      isDefault: json['isDefault'] as bool,
      description: json['description'] as String,
      projectId: json['projectId'] as String,
      userRoles: (json['userRoles'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, parseAccessRole(v as String?)),
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
    'projectId': projectId,
    'userRoles': userRoles.map((k, v) => MapEntry(k, v.name)),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    // include a changing field so edits break equality and trigger rebuilds
    updatedAt,
  ];
}
