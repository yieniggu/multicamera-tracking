import 'package:hive/hive.dart';

part 'group_model.g.dart';

@HiveType(typeId: 1)
class GroupModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String projectId;

  @HiveField(4)
  Map<String, String> userRoles; // userId → role (as string)

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.projectId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });
}
