import 'package:hive/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 2)
class ProjectModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isDefault;

  @HiveField(3)
  String description;

  @HiveField(4)
  Map<String, String> userRoles; // userId → role (as string)

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.description,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });
}
