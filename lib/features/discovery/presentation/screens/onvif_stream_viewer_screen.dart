import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class OnvifStreamViewerScreen extends StatefulWidget {
  final String rtspUrl;
  final String title;

  const OnvifStreamViewerScreen({
    super.key,
    required this.rtspUrl,
    required this.title,
  });

  @override
  State<OnvifStreamViewerScreen> createState() =>
      _OnvifStreamViewerScreenState();
}

class _OnvifStreamViewerScreenState extends State<OnvifStreamViewerScreen> {
  VlcPlayerController? _controller;
  Timer? _loadingTimeout;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createController();
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_loading || _error != null) return;
      setState(() => _error = 'Still connecting to stream...');
    });
  }

  void _createController() {
    _controller = VlcPlayerController.network(
      widget.rtspUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(),
    )..addListener(_onVlcChanged);

    _loading = true;
    _error = null;
  }

  void _onVlcChanged() {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;

    final value = ctrl.value;
    if (value.hasError) {
      setState(() {
        _loading = false;
        _error = value.errorDescription.trim().isNotEmpty
            ? value.errorDescription.trim()
            : 'Failed to open stream';
      });
      return;
    }

    final ready =
        value.isInitialized &&
        (value.isPlaying || value.position.inMilliseconds > 0);
    if (ready != !_loading) {
      setState(() {
        _loading = !ready;
        if (ready) _error = null;
      });
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      ctrl.removeListener(_onVlcChanged);
      try {
        ctrl.dispose();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.rtspUrl,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ctrl != null)
                  VlcPlayer(
                    controller: ctrl,
                    aspectRatio: 16 / 9,
                    placeholder: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Connecting...'),
                      ],
                    ),
                  ),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
