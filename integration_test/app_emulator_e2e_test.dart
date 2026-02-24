import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multicamera_tracking/config/dependency_config.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/firebase_options.dart';
import 'package:multicamera_tracking/main.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';
import 'package:multicamera_tracking/shared/presentation/bloc/app_locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _runFirebaseEmulatorE2E = bool.fromEnvironment(
  'RUN_FIREBASE_EMULATOR_E2E',
  defaultValue: false,
);
const String _configuredAuthHost = String.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_HOST',
  defaultValue: '',
);
const int _configuredAuthPort = int.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const String _configuredFirestoreHost = String.fromEnvironment(
  'FIRESTORE_EMULATOR_HOST',
  defaultValue: '',
);
const int _configuredFirestorePort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final dependencyConfig = DependencyConfig.emulators(
    authEmulatorHost: _configuredAuthHost.isEmpty
        ? _defaultEmulatorHost()
        : _configuredAuthHost,
    authEmulatorPort: _configuredAuthPort,
    firestoreEmulatorHost: _configuredFirestoreHost.isEmpty
        ? _defaultEmulatorHost()
        : _configuredFirestoreHost,
    firestoreEmulatorPort: _configuredFirestorePort,
    hiveBoxSuffix: 'it_e2e',
  );
  final admin = _FirebaseEmulatorAdmin(
    host: dependencyConfig.firestoreEmulatorHost,
    authPort: dependencyConfig.authEmulatorPort,
    firestorePort: dependencyConfig.firestoreEmulatorPort,
    projectId: DefaultFirebaseOptions.currentPlatform.projectId,
  );

  setUpAll(() async {
    if (!_runFirebaseEmulatorE2E) return;
    await resetDependencies(clearLocalData: true);
    await initDependencies(config: dependencyConfig);
    await admin.ensureReady();
  });

  tearDownAll(() async {
    if (!_runFirebaseEmulatorE2E) return;
    await resetDependencies(clearLocalData: true);
    admin.close();
  });

  setUp(() async {
    if (!_runFirebaseEmulatorE2E) return;
    await admin.wipeAll();
    await getIt<AuthRepository>().signOut();
    await getIt<GuestDataService>().clearLocalData();
    getIt<AppMode>().enterGuest();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets(
    'guest sign-in initializes local default project and group',
    (tester) async {
      final authBloc = await _pumpApp(tester);
      addTearDown(authBloc.close);

      await tester.tap(find.byKey(const Key('guest_sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_logout_button')), findsOneWidget);
      expect(getIt<AuthRepository>().currentUser?.id, 'local_guest');
      expect(getIt<AppMode>().isGuest, isTrue);

      final projects = await getIt<ProjectRepository>().getAll();
      expect(projects.length, 1);
      final groups = await getIt<GroupRepository>().getAllByProject(
        projects.first.id,
      );
      expect(groups.length, 1);
    },
    skip: !_runFirebaseEmulatorE2E,
  );

  testWidgets(
    'guest -> register email migrates local data and remains after re-login',
    (tester) async {
      final authBloc = await _pumpApp(tester);
      addTearDown(authBloc.close);

      await tester.tap(find.byKey(const Key('guest_sign_in_button')));
      await tester.pumpAndSettle();

      final seed = await _seedLocalGuestTree();
      final email = _uniqueEmail('fresh');
      const password = 'Passw0rd!';

      await tester.tap(find.byKey(const Key('guest_link_account_cta')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        email,
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        password,
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(getIt<AppMode>().isRemote, isTrue);
      expect(getIt<AuthRepository>().currentUser?.email, email);
      await _expectRemoteTreeMatches(seed);

      await tester.tap(find.byKey(const Key('home_logout_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login_email_field')), email);
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        password,
      );
      await tester.tap(find.byKey(const Key('email_sign_in_button')));
      await tester.pumpAndSettle();

      expect(getIt<AppMode>().isRemote, isTrue);
      await _expectRemoteTreeMatches(seed);
    },
    skip: !_runFirebaseEmulatorE2E,
  );

  testWidgets(
    'migration service merges and overwrites conflicting remote camera',
    (tester) async {
      final sourceUserId = 'local_guest';
      final targetUserId = 'target_${_uniqueSuffix()}';
      final now = DateTime.now();

      await getIt<ProjectLocalDatasource>().save(
        Project(
          id: 'local_project',
          name: 'Shared Project',
          description: 'local project',
          isDefault: true,
          userRoles: {sourceUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await getIt<GroupLocalDatasource>().save(
        Group(
          id: 'local_group',
          name: 'Shared Group',
          isDefault: true,
          description: 'local group',
          projectId: 'local_project',
          userRoles: {sourceUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await getIt<CameraLocalDatasource>().save(
        Camera(
          id: 'local_camera',
          name: 'Shared Camera',
          description: 'camera from local',
          rtspUrl: 'rtsp://local-camera',
          projectId: 'local_project',
          groupId: 'local_group',
          userRoles: {sourceUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );

      await getIt<ProjectRemoteDataSource>().save(
        Project(
          id: 'remote_project',
          name: 'Shared Project',
          description: 'remote project',
          isDefault: true,
          userRoles: {targetUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await getIt<GroupRemoteDatasource>().save(
        Group(
          id: 'remote_group',
          name: 'Shared Group',
          isDefault: true,
          description: 'remote group',
          projectId: 'remote_project',
          userRoles: {targetUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await getIt<CameraRemoteDatasource>().save(
        Camera(
          id: 'remote_camera',
          name: 'Shared Camera',
          description: 'camera from remote',
          rtspUrl: 'rtsp://remote-camera',
          projectId: 'remote_project',
          groupId: 'remote_group',
          userRoles: {targetUserId: AccessRole.admin},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final preview = await getIt<GuestDataMigrationService>().buildPreview(
        sourceUserId: sourceUserId,
        targetUserId: targetUserId,
      );
      expect(preview.targetHasData, isTrue);
      expect(preview.projectConflicts, isNotEmpty);

      const plan = GuestMigrationPlan(
        projectResolutions: {
          'local_project': ProjectMergeResolution(
            localProjectId: 'local_project',
            strategy: MergeStrategy.merge,
            targetRemoteProjectId: 'remote_project',
            groupResolutions: {
              'local_group': GroupMergeResolution(
                localGroupId: 'local_group',
                strategy: MergeStrategy.merge,
                targetRemoteGroupId: 'remote_group',
                cameraResolutions: {
                  'local_camera': CameraMergeResolution(
                    localCameraId: 'local_camera',
                    strategy: MergeStrategy.overwrite,
                    targetRemoteCameraId: 'remote_camera',
                  ),
                },
              ),
            },
          ),
        },
      );

      await getIt<GuestDataMigrationService>().migrate(
        sourceUserId: sourceUserId,
        targetUserId: targetUserId,
        plan: plan,
      );

      final remoteProjects = await getIt<ProjectRemoteDataSource>().getAll(
        targetUserId,
      );
      expect(remoteProjects.length, 1);
      final remoteGroups = await getIt<GroupRemoteDatasource>().getAllByProject(
        'remote_project',
      );
      expect(remoteGroups.length, 1);
      final remoteCameras = await getIt<CameraRemoteDatasource>().getAllByGroup(
        'remote_project',
        'remote_group',
      );
      expect(remoteCameras.length, 1);
      expect(remoteCameras.single.id, 'remote_camera');
      expect(remoteCameras.single.description, 'camera from local');
      expect(remoteCameras.single.rtspUrl, 'rtsp://local-camera');
    },
    skip: !_runFirebaseEmulatorE2E,
  );
}

Future<AuthBloc> _pumpApp(WidgetTester tester) async {
  final authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());
  final appLocaleCubit = getIt<AppLocaleCubit>()..hydrate();
  await tester.pumpWidget(
    MyApp(authBloc: authBloc, appLocaleCubit: appLocaleCubit),
  );
  await tester.pumpAndSettle();
  return authBloc;
}

Future<_LocalTreeSeed> _seedLocalGuestTree() async {
  final now = DateTime.now();
  final suffix = _uniqueSuffix();
  final projectName = 'Local Project $suffix';
  final groupName = 'Local Group $suffix';
  final cameraName = 'Local Camera $suffix';

  final user = getIt<AuthRepository>().currentUser;
  if (user == null) {
    throw StateError('Expected local guest user before seeding local data.');
  }

  final projects = await getIt<ProjectRepository>().getAll();
  if (projects.isEmpty) {
    throw StateError('Expected a default local project before migration seed.');
  }
  final localProject = projects.first;

  await getIt<ProjectRepository>().save(
    localProject.copyWith(
      name: projectName,
      description: 'local description $suffix',
      updatedAt: now,
    ),
  );

  final groups = await getIt<GroupRepository>().getAllByProject(
    localProject.id,
  );
  if (groups.isEmpty) {
    throw StateError('Expected a default local group before migration seed.');
  }
  final localGroup = groups.first;

  await getIt<GroupRepository>().save(
    localGroup.copyWith(
      name: groupName,
      description: 'local group description $suffix',
      updatedAt: now,
    ),
  );

  await getIt<CameraRepository>().save(
    Camera(
      id: 'local_camera_${_uniqueSuffix()}',
      name: cameraName,
      description: 'local camera description $suffix',
      rtspUrl: 'rtsp://local/$suffix',
      projectId: localProject.id,
      groupId: localGroup.id,
      userRoles: {user.id: AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    ),
  );

  return _LocalTreeSeed(
    projectName: projectName,
    groupName: groupName,
    cameraName: cameraName,
  );
}

Future<void> _expectRemoteTreeMatches(_LocalTreeSeed seed) async {
  final projects = await getIt<ProjectRepository>().getAll();
  final matchingProjects = projects.where((p) => p.name == seed.projectName);
  expect(matchingProjects.length, 1);
  final project = matchingProjects.first;

  final groups = await getIt<GroupRepository>().getAllByProject(project.id);
  final matchingGroups = groups.where((g) => g.name == seed.groupName);
  expect(matchingGroups.length, 1);
  final group = matchingGroups.first;

  final cameras = await getIt<CameraRepository>().getAllByGroup(
    project.id,
    group.id,
  );
  final matchingCameras = cameras.where((c) => c.name == seed.cameraName);
  expect(matchingCameras.length, 1);
}

String _defaultEmulatorHost() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return '127.0.0.1';
}

String _uniqueEmail(String prefix) {
  return '$prefix.${_uniqueSuffix()}@example.com';
}

String _uniqueSuffix() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

class _LocalTreeSeed {
  final String projectName;
  final String groupName;
  final String cameraName;

  const _LocalTreeSeed({
    required this.projectName,
    required this.groupName,
    required this.cameraName,
  });
}

class _FirebaseEmulatorAdmin {
  final String host;
  final int authPort;
  final int firestorePort;
  final String projectId;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  _FirebaseEmulatorAdmin({
    required this.host,
    required this.authPort,
    required this.firestorePort,
    required this.projectId,
  });

  Future<void> ensureReady() async {
    try {
      await wipeAll();
    } catch (e) {
      throw StateError(
        'Firebase emulators are not reachable at '
        'auth=$host:$authPort firestore=$host:$firestorePort for project=$projectId. '
        'Start emulators before running E2E tests. Original error: $e',
      );
    }
  }

  Future<void> wipeAll() async {
    await Future.wait([_wipeAuth(), _wipeFirestore()]);
  }

  void close() {
    _httpClient.close(force: true);
  }

  Future<void> _wipeAuth() async {
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: authPort,
      path: '/emulator/v1/projects/$projectId/accounts',
    );
    await _delete(uri);
  }

  Future<void> _wipeFirestore() async {
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: firestorePort,
      path: '/emulator/v1/projects/$projectId/databases/(default)/documents',
    );
    await _delete(uri);
  }

  Future<void> _delete(Uri uri) async {
    final request = await _httpClient.deleteUrl(uri);
    final response = await request.close();
    if (response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.noContent) {
      return;
    }

    final body = await response.transform(SystemEncoding().decoder).join();
    throw HttpException(
      'Unexpected status=${response.statusCode} body=$body',
      uri: uri,
    );
  }
}
