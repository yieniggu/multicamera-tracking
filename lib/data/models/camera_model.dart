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

  CameraModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rtspUrl,
    this.thumbnailUrl,
  });

  // Optional conversion helper
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'rtspUrl': rtspUrl,
  };
}
