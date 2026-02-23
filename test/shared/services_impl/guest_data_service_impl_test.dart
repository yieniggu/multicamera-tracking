import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/pending_auth_link.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/camera_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/group_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/project_model.dart';
import 'package:multicamera_tracking/shared/services_impl/guest_data_service_impl.dart';

class _NoopAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  void clearPendingAuthLink() {}

  @override
  AuthUser? get currentUser => null;

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async => false;

  @override
  PendingAuthLink? get pendingAuthLink => null;

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      null;

  @override
  Future<AuthUser?> signInAnonymously() async => null;

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      null;

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser?> signInWithMicrosoft() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  late Directory tempDir;
  late Box<ProjectModel> projectBox;
  late Box<GroupModel> groupBox;
  late Box<CameraModel> cameraBox;
  late GuestDataServiceImpl service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mct_guest_data_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CameraModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GroupModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProjectModelAdapter());
    }

    projectBox = await Hive.openBox<ProjectModel>('projects_box_guest_data');
    groupBox = await Hive.openBox<GroupModel>('groups_box_guest_data');
    cameraBox = await Hive.openBox<CameraModel>('cameras_box_guest_data');

    service = GuestDataServiceImpl(
      projectLocalDatasource: ProjectLocalDatasource(box: projectBox),
      groupLocalDatasource: GroupLocalDatasource(box: groupBox),
      cameraLocalDatasource: CameraLocalDatasource(box: cameraBox),
      authRepository: _NoopAuthRepository(),
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'hasDataToMigrate returns true when source owns at least one project',
    () async {
      final now = DateTime.now();
      await projectBox.put(
        'p-local',
        ProjectModel(
          id: 'p-local',
          name: 'Local Project',
          isDefault: true,
          description: 'Only project data',
          userRoles: {'local_guest': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final hasData = await service.hasDataToMigrate(
        sourceUserId: 'local_guest',
      );

      expect(hasData, isTrue);
    },
  );

  test(
    'resolveMigrationSourceUserId returns preferred source with project-only data',
    () async {
      final now = DateTime.now();
      await projectBox.put(
        'p-local',
        ProjectModel(
          id: 'p-local',
          name: 'Local Project',
          isDefault: true,
          description: 'Only project data',
          userRoles: {'local_guest': 'admin'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final source = await service.resolveMigrationSourceUserId(
        preferredSourceUserId: 'local_guest',
      );

      expect(source, 'local_guest');
    },
  );
}
