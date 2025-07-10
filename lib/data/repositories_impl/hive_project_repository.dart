import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:multicamera_tracking/data/models/project_model_mapper.dart';

class HiveProjectRepository implements ProjectRepository {
  final Box<ProjectModel> box;

  HiveProjectRepository({required this.box});

  @override
  Future<List<Project>> getAll() async {
    debugPrint("[HIVE-PROJ-REP] Getting all projects...");
    return box.values.map((e) => e.toEntity()).toList();
  }

  @override
  Future<Project?> getDefaultProject() async {
    debugPrint("[HIVE-PROJ-REP] Getting default project...");
    return box.values.isNotEmpty ? box.values.first.toEntity() : null;
  }

  @override
  Future<void> save(Project project) async {
    debugPrint("[HIVE-PROJ-REP] Saving project ${project.id}");
    await box.put(project.id, project.toModel());
  }
}
