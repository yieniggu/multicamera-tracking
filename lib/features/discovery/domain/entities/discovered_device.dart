import 'package:equatable/equatable.dart';

enum DiscoverySource { mdns, ssdp, deepScan, arp, probe }

enum DiscoveredDeviceType {
  unknown,
  camera,
  recorder,
  cameraOrRecorder,
  networkDevice,
}

enum DiscoveryConfidence { low, medium, high }

class DiscoveredDevice extends Equatable {
  final String ipAddress;
  final String? macAddress;
  final String? hostName;
  final String? deviceName;
  final String? vendor;
  final String? model;
  final DiscoverySource source;
  final DiscoveredDeviceType deviceType;
  final DiscoveryConfidence confidence;
  final bool onvifSupported;
  final bool rtspSupported;
  final bool requiresAuthentication;
  final bool authenticationVerified;
  final bool alreadyExists;
  final List<String> existingCameraNames;

  const DiscoveredDevice({
    required this.ipAddress,
    this.macAddress,
    this.hostName,
    this.deviceName,
    this.vendor,
    this.model,
    required this.source,
    this.deviceType = DiscoveredDeviceType.unknown,
    this.confidence = DiscoveryConfidence.low,
    this.onvifSupported = false,
    this.rtspSupported = false,
    this.requiresAuthentication = false,
    this.authenticationVerified = false,
    this.alreadyExists = false,
    this.existingCameraNames = const [],
  });

  String get dedupeKey => ipAddress;

  DiscoveredDevice copyWith({
    String? macAddress,
    String? hostName,
    String? deviceName,
    String? vendor,
    String? model,
    DiscoverySource? source,
    DiscoveredDeviceType? deviceType,
    DiscoveryConfidence? confidence,
    bool? onvifSupported,
    bool? rtspSupported,
    bool? requiresAuthentication,
    bool? authenticationVerified,
    bool? alreadyExists,
    List<String>? existingCameraNames,
  }) {
    return DiscoveredDevice(
      ipAddress: ipAddress,
      macAddress: macAddress ?? this.macAddress,
      hostName: hostName ?? this.hostName,
      deviceName: deviceName ?? this.deviceName,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      source: source ?? this.source,
      deviceType: deviceType ?? this.deviceType,
      confidence: confidence ?? this.confidence,
      onvifSupported: onvifSupported ?? this.onvifSupported,
      rtspSupported: rtspSupported ?? this.rtspSupported,
      requiresAuthentication:
          requiresAuthentication ?? this.requiresAuthentication,
      authenticationVerified:
          authenticationVerified ?? this.authenticationVerified,
      alreadyExists: alreadyExists ?? this.alreadyExists,
      existingCameraNames: existingCameraNames ?? this.existingCameraNames,
    );
  }

  DiscoveredDevice mergeWith(DiscoveredDevice other) {
    final mergedConfidence = _maxConfidence(confidence, other.confidence);
    final mergedType = _pickDeviceType(deviceType, other.deviceType);
    return DiscoveredDevice(
      ipAddress: ipAddress,
      macAddress: other.macAddress ?? macAddress,
      hostName: other.hostName ?? hostName,
      deviceName: other.deviceName ?? deviceName,
      vendor: other.vendor ?? vendor,
      model: other.model ?? model,
      source: other.source == DiscoverySource.probe ? source : other.source,
      deviceType: mergedType,
      confidence: mergedConfidence,
      onvifSupported: onvifSupported || other.onvifSupported,
      rtspSupported: rtspSupported || other.rtspSupported,
      requiresAuthentication:
          (requiresAuthentication || other.requiresAuthentication) &&
          !(authenticationVerified || other.authenticationVerified),
      authenticationVerified:
          authenticationVerified || other.authenticationVerified,
      alreadyExists: alreadyExists || other.alreadyExists,
      existingCameraNames: {
        ...existingCameraNames,
        ...other.existingCameraNames,
      }.toList(),
    );
  }

  static DiscoveryConfidence _maxConfidence(
    DiscoveryConfidence a,
    DiscoveryConfidence b,
  ) {
    if (a.index >= b.index) return a;
    return b;
  }

  static DiscoveredDeviceType _pickDeviceType(
    DiscoveredDeviceType current,
    DiscoveredDeviceType incoming,
  ) {
    if (incoming == DiscoveredDeviceType.unknown) return current;
    if (current == DiscoveredDeviceType.unknown) return incoming;
    if (current == incoming) return current;
    if (current == DiscoveredDeviceType.networkDevice) return incoming;
    if (incoming == DiscoveredDeviceType.networkDevice) return current;
    return DiscoveredDeviceType.cameraOrRecorder;
  }

  @override
  List<Object?> get props => [
    ipAddress,
    macAddress,
    hostName,
    deviceName,
    vendor,
    model,
    source,
    deviceType,
    confidence,
    onvifSupported,
    rtspSupported,
    requiresAuthentication,
    authenticationVerified,
    alreadyExists,
    existingCameraNames,
  ];
}
