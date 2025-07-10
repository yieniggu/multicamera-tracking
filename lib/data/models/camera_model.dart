import 'package:hive/hive.dart';

part 'camera_model.g.dart';

@HiveType(typeId: 0)
class CameraModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String rtspUrl;

  @HiveField(4)
  String? thumbnailUrl;

  @HiveField(5)
  String projectId; // ✅ NEW

  @HiveField(6)
  String groupId;

  @HiveField(7)
  Map<String, String> userRoles;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  CameraModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rtspUrl,
    this.thumbnailUrl,
    required this.projectId, // ✅ NEW
    required this.groupId,
    required this.userRoles,
    required this.createdAt,
    required this.updatedAt,
  });
}
