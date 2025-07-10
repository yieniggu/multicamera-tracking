import 'package:hive/hive.dart';

part 'group_model.g.dart';

@HiveType(typeId: 1)
class GroupModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isDefault;

  @HiveField(3)
  String description;

  @HiveField(4)
  String projectId;

  @HiveField(5)
  Map<String, String> userRoles; // userId → role (as string)

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.description,
    required this.projectId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });
}
