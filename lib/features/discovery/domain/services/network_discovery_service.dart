import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';

abstract class NetworkDiscoveryService {
  Stream<DiscoveredDevice> discover({required bool includeDeepScan});

  Future<void> stop();

  Future<DiscoveredDevice?> probeDevice(
    String ipAddress, {
    String? username,
    String? password,
  });

  Future<String?> fetchOnvifStreamUri(
    String ipAddress, {
    String? username,
    String? password,
  });
}
