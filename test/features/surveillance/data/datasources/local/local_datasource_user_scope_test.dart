import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/camera_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/project_model.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mct_local_scope_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CameraModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProjectModelAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'ProjectLocalDatasource.getAll returns only projects owned by user',
    () async {
      final box = await Hive.openBox<ProjectModel>('projects_box_test');
      final ds = ProjectLocalDatasource(box: box);
      final now = DateTime.now();

      await box.put(
        'p1',
        ProjectModel(
          id: 'p1',
          name: 'Project A',
          isDefault: true,
          description: 'A',
          userRoles: {'user-a': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await box.put(
        'p2',
        ProjectModel(
          id: 'p2',
          name: 'Project B',
          isDefault: false,
          description: 'B',
          userRoles: {'user-b': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final forA = await ds.getAll('user-a');
      final forB = await ds.getAll('user-b');
      final forC = await ds.getAll('user-c');

      expect(forA.map((e) => e.id).toList(), ['p1']);
      expect(forB.map((e) => e.id).toList(), ['p2']);
      expect(forC, isEmpty);
    },
  );

  test(
    'CameraLocalDatasource.getAll returns only cameras owned by user',
    () async {
      final box = await Hive.openBox<CameraModel>('cameras_box_test');
      final ds = CameraLocalDatasource(box: box);
      final now = DateTime.now();

      await box.put(
        'c1',
        CameraModel(
          id: 'c1',
          name: 'Cam A',
          description: 'A',
          rtspUrl: 'rtsp://a',
          projectId: 'p1',
          groupId: 'g1',
          userRoles: {'user-a': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await box.put(
        'c2',
        CameraModel(
          id: 'c2',
          name: 'Cam B',
          description: 'B',
          rtspUrl: 'rtsp://b',
          projectId: 'p2',
          groupId: 'g2',
          userRoles: {'user-b': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final forA = await ds.getAll('user-a');
      final forB = await ds.getAll('user-b');
      final forC = await ds.getAll('user-c');

      expect(forA.map((e) => e.id).toList(), ['c1']);
      expect(forB.map((e) => e.id).toList(), ['c2']);
      expect(forC, isEmpty);
    },
  );
}
