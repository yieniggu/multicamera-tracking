import 'package:hive/hive.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/group_model_mapper.dart';

class HiveGroupRepository implements GroupRepository {
  final Box<GroupModel> box;

  HiveGroupRepository({required this.box});

  @override
  Future<List<Group>> getAll() async {
    return box.values.map((e) => e.toEntity()).toList();
  }

  @override
  Future<Group?> getDefaultGroup(String projectId) async {
    try {
      final model = box.values.firstWhere((e) => e.projectId == projectId);
      return model.toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Group group) async {
    await box.put(group.id, group.toModel());
  }
}
