import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';
import 'package:multicamera_tracking/features/discovery/domain/services/network_discovery_service.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_state.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_all_cameras.dart';

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final NetworkDiscoveryService discoveryService;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final GetAllCamerasUseCase getAllCamerasUseCase;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Map<String, List<String>> _existingCameraNamesByIp = const {};

  DiscoveryBloc({
    required this.discoveryService,
    required this.getCurrentUserUseCase,
    required this.getAllCamerasUseCase,
  }) : super(const DiscoveryState.initial()) {
    on<StartDiscovery>(_onStartDiscovery);
    on<StopDiscovery>(_onStopDiscovery);
    on<AuthenticateDiscoveredDevice>(_onAuthenticateDevice);
    on<DiscoveryDeviceReceived>(_onDeviceReceived);
    on<DiscoveryScanCompleted>(_onScanCompleted);
    on<DiscoveryScanFailed>(_onScanFailed);
  }

  @override
  Future<void> close() async {
    await _scanSubscription?.cancel();
    await discoveryService.stop();
    return super.close();
  }

  Future<void> _onStartDiscovery(
    StartDiscovery event,
    Emitter<DiscoveryState> emit,
  ) async {
    await _scanSubscription?.cancel();
    await discoveryService.stop();

    emit(
      state.copyWith(
        status: DiscoveryStatus.scanning,
        devices: const [],
        includeDeepScan: event.includeDeepScan,
        authenticatingIps: const {},
        errorMessage: null,
      ),
    );

    await _loadExistingCameraIndex();
    debugPrint(
      '[DISCOVERY] Scan started deep=${event.includeDeepScan} existingIndexed=${_existingCameraNamesByIp.length}',
    );

    final stream = discoveryService.discover(
      includeDeepScan: event.includeDeepScan,
    );
    _scanSubscription = stream.listen(
      (device) => add(DiscoveryDeviceReceived(device)),
      onDone: () => add(const DiscoveryScanCompleted()),
      onError: (error, _) => add(DiscoveryScanFailed(error.toString())),
      cancelOnError: false,
    );
  }

  Future<void> _onStopDiscovery(
    StopDiscovery event,
    Emitter<DiscoveryState> emit,
  ) async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await discoveryService.stop();

    emit(
      state.copyWith(
        status: DiscoveryStatus.idle,
        authenticatingIps: const {},
        errorMessage: null,
      ),
    );
  }

  Future<void> _onAuthenticateDevice(
    AuthenticateDiscoveredDevice event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state.authenticatingIps.contains(event.ipAddress)) return;

    emit(
      state.copyWith(
        authenticatingIps: {...state.authenticatingIps, event.ipAddress},
      ),
    );

    try {
      final probed = await discoveryService.probeDevice(
        event.ipAddress,
        username: event.username,
        password: event.password,
      );
      if (probed != null) {
        add(DiscoveryDeviceReceived(probed));
        if (!probed.onvifSupported) {
          final reason = probed.requiresAuthentication
              ? 'ONVIF requires valid credentials for ${event.ipAddress}.'
              : 'ONVIF is not available on ${event.ipAddress}.';
          emit(
            state.copyWith(status: DiscoveryStatus.error, errorMessage: reason),
          );
        } else {
          emit(
            state.copyWith(
              status: state.status == DiscoveryStatus.scanning
                  ? DiscoveryStatus.scanning
                  : DiscoveryStatus.idle,
              errorMessage: null,
            ),
          );
        }
      } else {
        emit(
          state.copyWith(
            status: DiscoveryStatus.error,
            errorMessage:
                'Could not authenticate ${event.ipAddress}. Verify credentials or enable ONVIF.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DiscoveryStatus.error,
          errorMessage:
              'Authentication probe failed for ${event.ipAddress}: $e',
        ),
      );
    } finally {
      final updated = Set<String>.from(state.authenticatingIps)
        ..remove(event.ipAddress);
      emit(state.copyWith(authenticatingIps: updated));
    }
  }

  void _onDeviceReceived(
    DiscoveryDeviceReceived event,
    Emitter<DiscoveryState> emit,
  ) {
    final existing = <String, DiscoveredDevice>{
      for (final d in state.devices) d.dedupeKey: d,
    };
    final current = existing[event.device.dedupeKey];
    DiscoveredDevice merged;
    if (current == null) {
      merged = _markExisting(event.device);
      existing[event.device.dedupeKey] = merged;
    } else {
      merged = _markExisting(current.mergeWith(event.device));
      existing[event.device.dedupeKey] = merged;
    }

    final devices = existing.values.toList()
      ..sort((a, b) => a.ipAddress.compareTo(b.ipAddress));

    if (_isCameraRelated(merged)) {
      debugPrint(
        '[DISCOVERY] Related device ip=${merged.ipAddress} type=${merged.deviceType.name} conf=${merged.confidence.name} onvif=${merged.onvifSupported} rtsp=${merged.rtspSupported} authReq=${merged.requiresAuthentication} authOk=${merged.authenticationVerified} exists=${merged.alreadyExists}',
      );
    } else {
      debugPrint(
        '[DISCOVERY] Unrelated device ip=${merged.ipAddress} type=${merged.deviceType.name} source=${merged.source.name}',
      );
    }

    emit(state.copyWith(devices: devices));
  }

  void _onScanCompleted(
    DiscoveryScanCompleted event,
    Emitter<DiscoveryState> emit,
  ) {
    if (state.status == DiscoveryStatus.scanning) {
      emit(state.copyWith(status: DiscoveryStatus.idle));
    }
  }

  void _onScanFailed(DiscoveryScanFailed event, Emitter<DiscoveryState> emit) {
    emit(
      state.copyWith(
        status: DiscoveryStatus.error,
        errorMessage: event.message,
      ),
    );
  }

  Future<void> _loadExistingCameraIndex() async {
    try {
      final user = getCurrentUserUseCase();
      if (user == null) {
        _existingCameraNamesByIp = const {};
        return;
      }

      final cameras = await getAllCamerasUseCase(user.id);
      final byIp = <String, List<String>>{};
      for (final camera in cameras) {
        final host = _hostFromRtsp(camera.rtspUrl);
        if (host == null || host.isEmpty) continue;
        byIp.putIfAbsent(host, () => <String>[]).add(camera.name);
      }
      _existingCameraNamesByIp = byIp;
      debugPrint(
        '[DISCOVERY] Existing camera index built entries=${_existingCameraNamesByIp.length}',
      );
    } catch (_) {
      _existingCameraNamesByIp = const {};
      debugPrint('[DISCOVERY] Existing camera index unavailable');
    }
  }

  String? _hostFromRtsp(String rtspUrl) {
    final uri = Uri.tryParse(rtspUrl.trim());
    if (uri != null && uri.host.isNotEmpty) return uri.host;

    final authHost = RegExp(r'@([^/:]+)').firstMatch(rtspUrl);
    if (authHost != null) return authHost.group(1);

    final hostPort = RegExp(r'rtsp://([^/:]+)').firstMatch(rtspUrl);
    return hostPort?.group(1);
  }

  DiscoveredDevice _markExisting(DiscoveredDevice device) {
    final names = _existingCameraNamesByIp[device.ipAddress] ?? const [];
    if (names.isEmpty) return device;
    return device.copyWith(alreadyExists: true, existingCameraNames: names);
  }

  bool _isCameraRelated(DiscoveredDevice device) {
    return device.onvifSupported ||
        device.deviceType == DiscoveredDeviceType.camera ||
        device.deviceType == DiscoveredDeviceType.recorder ||
        device.deviceType == DiscoveredDeviceType.cameraOrRecorder;
  }
}
