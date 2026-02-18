import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';

enum DiscoveryStatus { idle, scanning, error }

class DiscoveryState extends Equatable {
  static const _errorUnchanged = Object();

  final DiscoveryStatus status;
  final List<DiscoveredDevice> devices;
  final bool includeDeepScan;
  final Set<String> authenticatingIps;
  final String? errorMessage;

  const DiscoveryState({
    required this.status,
    required this.devices,
    required this.includeDeepScan,
    this.authenticatingIps = const {},
    this.errorMessage,
  });

  const DiscoveryState.initial()
    : status = DiscoveryStatus.idle,
      devices = const [],
      includeDeepScan = true,
      authenticatingIps = const {},
      errorMessage = null;

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    List<DiscoveredDevice>? devices,
    bool? includeDeepScan,
    Set<String>? authenticatingIps,
    Object? errorMessage = _errorUnchanged,
  }) {
    return DiscoveryState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      includeDeepScan: includeDeepScan ?? this.includeDeepScan,
      authenticatingIps: authenticatingIps ?? this.authenticatingIps,
      errorMessage: identical(errorMessage, _errorUnchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    devices,
    includeDeepScan,
    authenticatingIps,
    errorMessage,
  ];
}
