import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';
import 'package:multicamera_tracking/features/discovery/domain/services/network_discovery_service.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:multicamera_tracking/features/discovery/presentation/screens/camera_discovery_screen.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_all_cameras.dart';

class _FakeNetworkDiscoveryService implements NetworkDiscoveryService {
  final Map<String, DiscoveredDevice> probeResults = {};
  final Map<String, String> streamUriResults = {};

  @override
  Stream<DiscoveredDevice> discover({required bool includeDeepScan}) =>
      const Stream.empty();

  @override
  Future<DiscoveredDevice?> probeDevice(
    String ipAddress, {
    String? username,
    String? password,
  }) async => probeResults[ipAddress];

  @override
  Future<String?> fetchOnvifStreamUri(
    String ipAddress, {
    String? username,
    String? password,
  }) async => streamUriResults[ipAddress];

  @override
  Future<void> stop() async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(id: 'u1');

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      currentUser;

  @override
  Future<AuthUser?> signInAnonymously() async => currentUser;

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      currentUser;

  @override
  Future<void> signOut() async {}
}

class _FakeCameraRepository implements CameraRepository {
  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {}

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {}

  @override
  Future<List<Camera>> getAll(String userId) async => const [];

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async =>
      const [];

  @override
  Future<void> save(Camera camera) async {}
}

void main() {
  DiscoveryBloc buildBloc([_FakeNetworkDiscoveryService? service]) {
    final fakeService = service ?? _FakeNetworkDiscoveryService();
    return DiscoveryBloc(
      discoveryService: fakeService,
      getCurrentUserUseCase: GetCurrentUserUseCase(_FakeAuthRepository()),
      getAllCamerasUseCase: GetAllCamerasUseCase(_FakeCameraRepository()),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, DiscoveryBloc bloc) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const CameraDiscoveryScreen(),
        ),
      ),
    );
  }

  testWidgets('hides unrelated devices by default and reveals on toggle', (
    tester,
  ) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await pumpScreen(tester, bloc);

    bloc.add(
      const DiscoveryDeviceReceived(
        DiscoveredDevice(
          ipAddress: '192.168.1.10',
          source: DiscoverySource.probe,
          deviceType: DiscoveredDeviceType.networkDevice,
          confidence: DiscoveryConfidence.medium,
        ),
      ),
    );
    bloc.add(
      const DiscoveryDeviceReceived(
        DiscoveredDevice(
          ipAddress: '192.168.1.11',
          source: DiscoverySource.probe,
          deviceType: DiscoveredDeviceType.camera,
          confidence: DiscoveryConfidence.high,
          onvifSupported: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Showing 1 of 2 found devices'), findsOneWidget);
    expect(find.text('Show unrelated devices (1)'), findsOneWidget);
    expect(find.text('Network Device'), findsNothing);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.text('Show unrelated devices (1)'));
    await tester.pump();

    expect(find.text('Hide unrelated devices (1)'), findsOneWidget);
    expect(find.text('Network Device'), findsOneWidget);
  });

  testWidgets('supports scrolling to later discovered devices', (tester) async {
    tester.view.physicalSize = const Size(390, 620);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = buildBloc();
    addTearDown(bloc.close);
    await pumpScreen(tester, bloc);

    for (var i = 1; i <= 4; i++) {
      bloc.add(
        DiscoveryDeviceReceived(
          DiscoveredDevice(
            ipAddress: '192.168.1.${200 + i}',
            deviceName: 'Cam $i',
            source: DiscoverySource.probe,
            deviceType: DiscoveredDeviceType.camera,
            confidence: DiscoveryConfidence.high,
            onvifSupported: true,
          ),
        ),
      );
    }
    await tester.pump();

    expect(find.text('Cam 4'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Cam 4'), findsOneWidget);
  });

  testWidgets('shows ONVIF config dialog for non-onvif devices', (
    tester,
  ) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await pumpScreen(tester, bloc);

    bloc.add(
      const DiscoveryDeviceReceived(
        DiscoveredDevice(
          ipAddress: '192.168.1.204',
          source: DiscoverySource.probe,
          deviceType: DiscoveredDeviceType.networkDevice,
          confidence: DiscoveryConfidence.medium,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Show unrelated devices (1)'));
    await tester.pump();
    await tester.tap(find.text('Configure ONVIF'));
    await tester.pumpAndSettle();

    expect(find.text('ONVIF Configuration Error'), findsOneWidget);
    expect(
      find.textContaining('Device is not compatible with ONVIF.'),
      findsOneWidget,
    );
  });

  testWidgets('prompts for credentials only after auth is required', (
    tester,
  ) async {
    final service = _FakeNetworkDiscoveryService();
    service.probeResults['192.168.1.205'] = const DiscoveredDevice(
      ipAddress: '192.168.1.205',
      source: DiscoverySource.probe,
      requiresAuthentication: true,
      onvifSupported: false,
    );

    final bloc = buildBloc(service);
    addTearDown(bloc.close);
    await pumpScreen(tester, bloc);

    bloc.add(
      const DiscoveryDeviceReceived(
        DiscoveredDevice(
          ipAddress: '192.168.1.205',
          source: DiscoverySource.probe,
          deviceType: DiscoveredDeviceType.networkDevice,
          confidence: DiscoveryConfidence.medium,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Show unrelated devices (1)'));
    await tester.pump();
    await tester.tap(find.text('Configure ONVIF'));
    await tester.pumpAndSettle();

    expect(find.text('ONVIF Authentication (192.168.1.205)'), findsOneWidget);
    expect(find.text('Authenticate'), findsOneWidget);
  });
}
