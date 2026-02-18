import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';

class DiscoveredDeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback? onConfigure;
  final VoidCallback? onAuthenticate;
  final bool isAuthenticating;

  const DiscoveredDeviceTile({
    super.key,
    required this.device,
    this.onConfigure,
    this.onAuthenticate,
    this.isAuthenticating = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = device.deviceName ?? device.hostName ?? 'Unknown Device';
    final details = <String>[
      'IP: ${device.ipAddress}',
      'MAC: ${device.macAddress ?? '-'}',
      'Host: ${device.hostName ?? '-'}',
      'Vendor: ${device.vendor ?? '-'}',
      'Model: ${device.model ?? '-'}',
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.videocam_outlined),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(_typeLabel(device.deviceType)),
                _chip('Confidence: ${_confidenceLabel(device.confidence)}'),
                if (device.onvifSupported) _chip('ONVIF'),
                if (device.alreadyExists) _chip('Already Added'),
              ],
            ),
            const SizedBox(height: 6),
            for (final line in details) Text(line),
            const SizedBox(height: 4),
            Text('Source: ${_sourceLabel(device.source)}'),
            if (device.alreadyExists && device.existingCameraNames.isNotEmpty)
              Text('Matches: ${device.existingCameraNames.join(', ')}'),
            if (onConfigure != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune),
                  label: const Text('Configure ONVIF'),
                ),
              ),
            if (device.requiresAuthentication && !device.authenticationVerified)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: isAuthenticating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: onAuthenticate,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Authenticate Device'),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black12,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  String _typeLabel(DiscoveredDeviceType type) {
    switch (type) {
      case DiscoveredDeviceType.camera:
        return 'Camera';
      case DiscoveredDeviceType.recorder:
        return 'Recorder';
      case DiscoveredDeviceType.cameraOrRecorder:
        return 'Camera/Recorder';
      case DiscoveredDeviceType.networkDevice:
        return 'Network Device';
      case DiscoveredDeviceType.unknown:
        return 'Unknown';
    }
  }

  String _confidenceLabel(DiscoveryConfidence confidence) {
    switch (confidence) {
      case DiscoveryConfidence.low:
        return 'Low';
      case DiscoveryConfidence.medium:
        return 'Medium';
      case DiscoveryConfidence.high:
        return 'High';
    }
  }

  String _sourceLabel(DiscoverySource source) {
    switch (source) {
      case DiscoverySource.mdns:
        return 'mDNS';
      case DiscoverySource.ssdp:
        return 'SSDP';
      case DiscoverySource.deepScan:
        return 'Deep Scan';
      case DiscoverySource.arp:
        return 'ARP';
      case DiscoverySource.probe:
        return 'Probe';
    }
  }
}
