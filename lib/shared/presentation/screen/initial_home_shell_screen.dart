import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/discovery/presentation/screens/camera_discovery_screen.dart';
import 'package:multicamera_tracking/shared/presentation/screen/home_screen.dart';

class InitialHomeShellScreen extends StatefulWidget {
  final bool isGuest;
  final WidgetBuilder? projectsTabBuilder;
  final WidgetBuilder? discoveryTabBuilder;

  const InitialHomeShellScreen({
    super.key,
    required this.isGuest,
    this.projectsTabBuilder,
    this.discoveryTabBuilder,
  });

  @override
  State<InitialHomeShellScreen> createState() => _InitialHomeShellScreenState();
}

class _InitialHomeShellScreenState extends State<InitialHomeShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final projectsTab =
        widget.projectsTabBuilder?.call(context) ??
        HomeScreen(isGuest: widget.isGuest, showGuestLoginCta: false);
    final discoveryTab =
        widget.discoveryTabBuilder?.call(context) ??
        const CameraDiscoveryScreen();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [projectsTab, discoveryTab],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_outlined),
            activeIcon: Icon(Icons.folder_open),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar_outlined),
            activeIcon: Icon(Icons.radar),
            label: 'Discovery',
          ),
        ],
      ),
    );
  }
}
