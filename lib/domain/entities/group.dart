enum AccessRole { admin, editor, viewer }

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
}
