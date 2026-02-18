import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_state.dart';
import 'package:multicamera_tracking/features/discovery/presentation/screens/onvif_stream_viewer_screen.dart';
import 'package:multicamera_tracking/features/discovery/presentation/widgets/discovered_device_tile.dart';

class CameraDiscoveryScreen extends StatefulWidget {
  const CameraDiscoveryScreen({super.key});

  @override
  State<CameraDiscoveryScreen> createState() => _CameraDiscoveryScreenState();
}

class _CameraDiscoveryScreenState extends State<CameraDiscoveryScreen> {
  bool _includeDeepScan = true;
  bool _showUnrelatedDevices = false;

  void _startScan() {
    setState(() => _showUnrelatedDevices = false);
    context.read<DiscoveryBloc>().add(
      StartDiscovery(includeDeepScan: _includeDeepScan),
    );
  }

  void _stopScan() {
    context.read<DiscoveryBloc>().add(const StopDiscovery());
  }

  Future<void> _configureDevice(DiscoveredDevice device) async {
    await _runOnvifConfigurationFlow(device.ipAddress);
  }

  Future<void> _runOnvifConfigurationFlow(
    String ipAddress, {
    String username = '',
    String password = '',
    bool allowCredentialPrompt = true,
  }) async {
    if (!mounted) return;
    _showLoadingDialog('Checking ONVIF compatibility...');

    DiscoveredDevice? probe;
    try {
      probe = await context.read<DiscoveryBloc>().discoveryService.probeDevice(
        ipAddress,
        username: username,
        password: password,
      );
    } catch (_) {
      probe = null;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;
    if (probe != null) {
      context.read<DiscoveryBloc>().add(DiscoveryDeviceReceived(probe));
    }

    if (probe == null || !probe.onvifSupported) {
      if ((probe?.requiresAuthentication ?? false) && allowCredentialPrompt) {
        final auth = await _promptOnvifCredentials(
          ipAddress,
          reason: 'ONVIF requires authentication for this device.',
        );
        if (auth == null || !mounted) return;

        await _runOnvifConfigurationFlow(
          ipAddress,
          username: auth.username,
          password: auth.password,
          allowCredentialPrompt: false,
        );
        return;
      }

      _showConfigureError('Device is not compatible with ONVIF.');
      return;
    }

    await _openOnvifStream(
      ipAddress: ipAddress,
      username: username,
      password: password,
      allowCredentialPrompt: allowCredentialPrompt,
    );
  }

  Future<_AuthAttempt?> _promptOnvifCredentials(
    String ipAddress, {
    String? reason,
  }) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ONVIF Authentication ($ipAddress)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reason ?? 'Enter credentials for ONVIF authentication.'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, true);
              },
              child: const Text('Authenticate'),
            ),
          ],
        );
      },
    );

    if (submit != true) return null;
    return _AuthAttempt(
      username: usernameController.text.trim(),
      password: passwordController.text,
    );
  }

  Future<void> _openOnvifStream({
    required String ipAddress,
    required String username,
    required String password,
    required bool allowCredentialPrompt,
  }) async {
    if (!mounted) return;
    _showLoadingDialog('Retrieving ONVIF stream URI...');

    String? streamUri;
    try {
      streamUri = await context
          .read<DiscoveryBloc>()
          .discoveryService
          .fetchOnvifStreamUri(
            ipAddress,
            username: username,
            password: password,
          );
    } catch (_) {
      streamUri = null;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;
    final resolvedStreamUri = streamUri;
    if (resolvedStreamUri == null || resolvedStreamUri.isEmpty) {
      if (username.trim().isEmpty && allowCredentialPrompt) {
        final auth = await _promptOnvifCredentials(
          ipAddress,
          reason: 'ONVIF stream requires authentication.',
        );
        if (auth == null || !mounted) return;

        await _runOnvifConfigurationFlow(
          ipAddress,
          username: auth.username,
          password: auth.password,
          allowCredentialPrompt: false,
        );
        return;
      }
      _showConfigureError('Device is not compatible with ONVIF streaming.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnvifStreamViewerScreen(
          rtspUrl: resolvedStreamUri,
          title: 'ONVIF Stream - $ipAddress',
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  void _showConfigureError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ONVIF Configuration Error'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Discovery')),
      body: BlocBuilder<DiscoveryBloc, DiscoveryState>(
        builder: (context, state) {
          final isScanning = state.status == DiscoveryStatus.scanning;
          final cameraRelatedDevices = state.devices
              .where(_isCameraRelated)
              .toList();
          final unrelatedDevices = state.devices
              .where((d) => !_isCameraRelated(d))
              .toList();
          final visibleDevices = _showUnrelatedDevices
              ? state.devices
              : cameraRelatedDevices;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.status == DiscoveryStatus.error &&
                        state.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: isScanning ? null : _startScan,
                          icon: const Icon(Icons.radar),
                          label: const Text('Scan LAN'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isScanning ? _stopScan : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _includeDeepScan,
                      onChanged: isScanning
                          ? null
                          : (value) {
                              setState(() => _includeDeepScan = value ?? true);
                            },
                      title: const Text('Deep Scan (/24 common camera ports)'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Text(
                      _statusLine(state),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (unrelatedDevices.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Showing ${visibleDevices.length} of ${state.devices.length} found devices',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showUnrelatedDevices =
                                      !_showUnrelatedDevices;
                                });
                              },
                              icon: Icon(
                                _showUnrelatedDevices
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              label: Text(
                                _showUnrelatedDevices
                                    ? 'Hide unrelated devices (${unrelatedDevices.length})'
                                    : 'Show unrelated devices (${unrelatedDevices.length})',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: visibleDevices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isScanning
                                    ? 'Scanning local network...'
                                    : (unrelatedDevices.isNotEmpty
                                          ? 'No camera devices found. ${unrelatedDevices.length} unrelated device(s) were hidden.'
                                          : 'No devices discovered yet.'),
                                textAlign: TextAlign.center,
                              ),
                              if (!isScanning && unrelatedDevices.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showUnrelatedDevices = true;
                                      });
                                    },
                                    child: const Text(
                                      'Show unrelated found devices',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _startScan(),
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            bottom:
                                kBottomNavigationBarHeight +
                                MediaQuery.of(context).padding.bottom +
                                16,
                          ),
                          itemCount: visibleDevices.length,
                          itemBuilder: (context, index) {
                            final device = visibleDevices[index];
                            return DiscoveredDeviceTile(
                              device: device,
                              onConfigure: () => _configureDevice(device),
                              isAuthenticating: state.authenticatingIps
                                  .contains(device.ipAddress),
                              onAuthenticate:
                                  device.requiresAuthentication &&
                                      !device.authenticationVerified
                                  ? () => _configureDevice(device)
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isCameraRelated(DiscoveredDevice device) {
    return device.onvifSupported ||
        device.deviceType == DiscoveredDeviceType.camera ||
        device.deviceType == DiscoveredDeviceType.recorder ||
        device.deviceType == DiscoveredDeviceType.cameraOrRecorder;
  }

  String _statusLine(DiscoveryState state) {
    switch (state.status) {
      case DiscoveryStatus.idle:
        return 'Status: Idle';
      case DiscoveryStatus.scanning:
        return 'Status: Scanning';
      case DiscoveryStatus.error:
        return 'Status: Error - ${state.errorMessage ?? 'unknown'}';
    }
  }
}

class _AuthAttempt {
  final String username;
  final String password;

  const _AuthAttempt({required this.username, required this.password});
}
