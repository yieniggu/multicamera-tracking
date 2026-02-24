import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:multicamera_tracking/shared/services_impl/init_user_data_service_impl.dart';

class _MockProjectRepository extends Mock implements ProjectRepository {}

class _MockGroupRepository extends Mock implements GroupRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserProfileRepository extends Mock
    implements UserProfileRepository {}

void main() {
  late _MockProjectRepository projectRepository;
  late _MockGroupRepository groupRepository;
  late _MockAuthRepository authRepository;
  late _MockUserProfileRepository userProfileRepository;
  late InitUserDataServiceImpl service;

  setUp(() {
    projectRepository = _MockProjectRepository();
    groupRepository = _MockGroupRepository();
    authRepository = _MockAuthRepository();
    userProfileRepository = _MockUserProfileRepository();

    service = InitUserDataServiceImpl(
      projectRepository: projectRepository,
      groupRepository: groupRepository,
      authRepository: authRepository,
      userProfileRepository: userProfileRepository,
    );

    final now = DateTime.now();
    final defaultProject = Project(
      id: 'p1',
      name: 'Default Project',
      description: 'Default',
      isDefault: true,
      userRoles: const {'u1': AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    );
    final defaultGroup = Group(
      id: 'g1',
      name: 'Default Group',
      isDefault: true,
      description: 'Default',
      projectId: 'p1',
      userRoles: const {'u1': AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    );

    when(
      () => projectRepository.getAll(),
    ).thenAnswer((_) async => [defaultProject]);
    when(
      () => groupRepository.getAllByProject('p1'),
    ).thenAnswer((_) async => [defaultGroup]);
    when(
      () => userProfileRepository.ensureCurrentUserProfileInitialized(),
    ).thenAnswer((_) async {});
  });

  test(
    'ensures profile initialization for authenticated non-guest users',
    () async {
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(id: 'u1', email: 'u1@example.com'));

      await service.ensureDefaultProjectAndGroup();

      verify(
        () => userProfileRepository.ensureCurrentUserProfileInitialized(),
      ).called(1);
      verify(() => projectRepository.getAll()).called(1);
    },
  );

  test('skips profile initialization for guest users', () async {
    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(id: 'local_guest', isAnonymous: true));

    await service.ensureDefaultProjectAndGroup();

    verifyNever(
      () => userProfileRepository.ensureCurrentUserProfileInitialized(),
    );
    verify(() => projectRepository.getAll()).called(1);
  });
}
