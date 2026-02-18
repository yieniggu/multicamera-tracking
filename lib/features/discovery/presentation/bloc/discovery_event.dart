import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';

abstract class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();

  @override
  List<Object?> get props => [];
}

class StartDiscovery extends DiscoveryEvent {
  final bool includeDeepScan;

  const StartDiscovery({required this.includeDeepScan});

  @override
  List<Object?> get props => [includeDeepScan];
}

class StopDiscovery extends DiscoveryEvent {
  const StopDiscovery();
}

class AuthenticateDiscoveredDevice extends DiscoveryEvent {
  final String ipAddress;
  final String username;
  final String password;

  const AuthenticateDiscoveredDevice({
    required this.ipAddress,
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [ipAddress, username, password];
}

class DiscoveryDeviceReceived extends DiscoveryEvent {
  final DiscoveredDevice device;

  const DiscoveryDeviceReceived(this.device);

  @override
  List<Object?> get props => [device];
}

class DiscoveryScanCompleted extends DiscoveryEvent {
  const DiscoveryScanCompleted();
}

class DiscoveryScanFailed extends DiscoveryEvent {
  final String message;

  const DiscoveryScanFailed(this.message);

  @override
  List<Object?> get props => [message];
}
