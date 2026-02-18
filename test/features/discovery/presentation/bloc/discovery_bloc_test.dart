import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';
import 'package:multicamera_tracking/features/discovery/domain/services/network_discovery_service.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_state.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_all_cameras.dart';

class _FakeNetworkDiscoveryService implements NetworkDiscoveryService {
  final _controller = StreamController<DiscoveredDevice>.broadcast();
  bool stopCalled = false;
  bool? lastIncludeDeepScan;
  final Map<String, DiscoveredDevice> probeResults = {};
  final Map<String, String> streamUriResults = {};
  int probeCalls = 0;

  @override
  Stream<DiscoveredDevice> discover({required bool includeDeepScan}) {
    lastIncludeDeepScan = includeDeepScan;
    return _controller.stream;
  }

  void emitDevice(DiscoveredDevice device) {
    _controller.add(device);
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<DiscoveredDevice?> probeDevice(
    String ipAddress, {
    String? username,
    String? password,
  }) async {
    probeCalls += 1;
    return probeResults[ipAddress];
  }

  @override
  Future<String?> fetchOnvifStreamUri(
    String ipAddress, {
    String? username,
    String? password,
  }) async => streamUriResults[ipAddress];

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeAuthRepository implements AuthRepository {
  final AuthUser? _current;

  _FakeAuthRepository(this._current);

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      _current;

  @override
  Future<AuthUser?> signInAnonymously() async => _current;

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      _current;

  @override
  Future<void> signOut() async {}
}

class _FakeCameraRepository implements CameraRepository {
  final List<Camera> cameras;

  _FakeCameraRepository(this.cameras);

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {}

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {}

  @override
  Future<List<Camera>> getAll(String userId) async => cameras;

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async =>
      const [];

  @override
  Future<void> save(Camera camera) async {}
}

void main() {
  late _FakeNetworkDiscoveryService service;
  late DiscoveryBloc bloc;

  Camera cameraFromIp(String ip, String name) {
    final now = DateTime(2026, 2, 17);
    return Camera(
      id: 'cam-$ip',
      name: name,
      description: '',
      rtspUrl: 'rtsp://admin:1234@$ip:554/stream',
      projectId: 'project-1',
      groupId: 'group-1',
      userRoles: const {'u1': AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    service = _FakeNetworkDiscoveryService();
    final authUseCase = GetCurrentUserUseCase(
      _FakeAuthRepository(const AuthUser(id: 'u1')),
    );
    final getAllCameras = GetAllCamerasUseCase(
      _FakeCameraRepository([cameraFromIp('192.168.1.42', 'Front Door')]),
    );

    bloc = DiscoveryBloc(
      discoveryService: service,
      getCurrentUserUseCase: authUseCase,
      getAllCamerasUseCase: getAllCameras,
    );
  });

  tearDown(() async {
    await bloc.close();
    await service.dispose();
  });

  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('starts scan in deep mode and moves to scanning state', () async {
    bloc.add(const StartDiscovery(includeDeepScan: true));
    await flush();

    expect(service.lastIncludeDeepScan, isTrue);
    expect(bloc.state.status, DiscoveryStatus.scanning);
  });

  test('merges updates from same ip and flags existing saved camera', () async {
    bloc.add(const StartDiscovery(includeDeepScan: true));
    await flush();

    service.emitDevice(
      const DiscoveredDevice(
        ipAddress: '192.168.1.42',
        source: DiscoverySource.deepScan,
      ),
    );
    await flush();

    service.emitDevice(
      const DiscoveredDevice(
        ipAddress: '192.168.1.42',
        deviceName: 'Garage Cam',
        vendor: 'AcmeVision',
        source: DiscoverySource.ssdp,
      ),
    );
    await flush();

    expect(bloc.state.devices.length, 1);
    final device = bloc.state.devices.single;
    expect(device.ipAddress, '192.168.1.42');
    expect(device.deviceName, 'Garage Cam');
    expect(device.vendor, 'AcmeVision');
    expect(device.source, DiscoverySource.ssdp);
    expect(device.alreadyExists, isTrue);
    expect(device.existingCameraNames, contains('Front Door'));
  });

  test('auth event reprobes device and updates auth flags', () async {
    service.probeResults['192.168.1.9'] = const DiscoveredDevice(
      ipAddress: '192.168.1.9',
      source: DiscoverySource.probe,
      onvifSupported: true,
      rtspSupported: true,
      authenticationVerified: true,
      requiresAuthentication: false,
      deviceType: DiscoveredDeviceType.recorder,
      confidence: DiscoveryConfidence.high,
    );

    bloc.add(const StartDiscovery(includeDeepScan: true));
    await flush();

    service.emitDevice(
      const DiscoveredDevice(
        ipAddress: '192.168.1.9',
        source: DiscoverySource.ssdp,
        requiresAuthentication: true,
      ),
    );
    await flush();

    bloc.add(
      const AuthenticateDiscoveredDevice(
        ipAddress: '192.168.1.9',
        username: 'admin',
        password: 'secret',
      ),
    );
    await flush();
    await flush();

    final device = bloc.state.devices.firstWhere(
      (d) => d.ipAddress == '192.168.1.9',
    );
    expect(service.probeCalls, greaterThan(0));
    expect(device.authenticationVerified, isTrue);
    expect(device.requiresAuthentication, isFalse);
    expect(device.deviceType, DiscoveredDeviceType.recorder);
  });

  test('auth event returns explicit error when onvif is unavailable', () async {
    service.probeResults['192.168.1.204'] = const DiscoveredDevice(
      ipAddress: '192.168.1.204',
      source: DiscoverySource.probe,
      onvifSupported: false,
      rtspSupported: true,
      requiresAuthentication: false,
      deviceType: DiscoveredDeviceType.networkDevice,
      confidence: DiscoveryConfidence.medium,
    );

    bloc.add(const StartDiscovery(includeDeepScan: true));
    await flush();

    service.emitDevice(
      const DiscoveredDevice(
        ipAddress: '192.168.1.204',
        source: DiscoverySource.ssdp,
      ),
    );
    await flush();

    bloc.add(
      const AuthenticateDiscoveredDevice(
        ipAddress: '192.168.1.204',
        username: '',
        password: '',
      ),
    );
    await flush();
    await flush();

    expect(bloc.state.status, DiscoveryStatus.error);
    expect(bloc.state.errorMessage, 'ONVIF is not available on 192.168.1.204.');
  });

  test('stop scan calls discovery service stop and updates state', () async {
    bloc.add(const StartDiscovery(includeDeepScan: false));
    await flush();

    bloc.add(const StopDiscovery());
    await flush();

    expect(service.stopCalled, isTrue);
    expect(bloc.state.status, DiscoveryStatus.idle);
  });
}
