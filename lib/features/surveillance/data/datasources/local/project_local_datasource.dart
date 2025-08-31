import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/project_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/project_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/project_model_mapper.dart';

class ProjectLocalDatasource implements ProjectDataSource {
  final Box<ProjectModel> box;

  ProjectLocalDatasource({required this.box});

  @override
  Future<List<Project>> getAll(String? userId) async {
    debugPrint("[PROJ-LOCAL-DS] Getting all projects...");

    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> save(Project project) async {
    debugPrint("[PROJ-LOCAL-DS] Saving new project: ${project.toString()}");
    final existing = box.get(project.id);
    final incoming = project.toModel();

    // Only write if something actually changed
    if (existing == null || existing != incoming) {
      await box.put(project.id, incoming);
    }
  }

  @override
  Future<void> delete(String id) async {
    debugPrint("[PROJ-LOCAL-DS] Deleting project with it: $id");

    final model = box.get(id);
    if (model != null && (model.isDefault)) {
      throw Exception("Cannot delete default project.");
    }
    await box.delete(id);
  }
}
