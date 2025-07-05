import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../../domain/entities/camera.dart';

class CameraPlayerScreen extends StatefulWidget {
  final Camera camera;

  const CameraPlayerScreen({super.key, required this.camera});

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  late VlcPlayerController _vlcController;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _vlcController = VlcPlayerController.network(
      widget.camera.rtspUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  @override
  void dispose() {
    _vlcController.dispose();
    _resetOrientation();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _resetOrientation();
    }
  }

  void _resetOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final player = VlcPlayer(
      controller: _vlcController,
      aspectRatio: 16 / 9,
      placeholder: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: _isFullscreen
          ? null
          : AppBar(title: Text(widget.camera.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: player),
            if (!_isFullscreen) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.camera.description),
              ),
              ElevatedButton.icon(
                onPressed: _toggleFullscreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text("Fullscreen"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
