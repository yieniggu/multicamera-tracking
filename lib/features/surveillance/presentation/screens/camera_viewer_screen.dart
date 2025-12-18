import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_state.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_event.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_state.dart';

class CameraViewerScreen extends StatefulWidget {
  final String projectId;
  final String initialGroupId;
  final String initialCameraId;

  const CameraViewerScreen({
    super.key,
    required this.projectId,
    required this.initialGroupId,
    required this.initialCameraId,
  });

  @override
  State<CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<CameraViewerScreen> {
  final Set<String> _requestedGroups = {};
  late final PageController _pageController;

  bool _isFullscreen = false;

  // Overlay behavior
  bool _infoCollapsed = false;
  Timer? _landscapeAutoHideTimer;

  String _currentCameraId = '';
  int _currentIndex = 0;

  List<String> _lastSequenceIds = const [];

  @override
  void initState() {
    super.initState();
    _currentCameraId = widget.initialCameraId;
    _pageController = PageController();

    context.read<GroupBloc>().add(LoadGroupsByProject(widget.projectId));
    _requestCamerasForGroup(widget.projectId, widget.initialGroupId);
  }

  @override
  void dispose() {
    _landscapeAutoHideTimer?.cancel();
    _pageController.dispose();
    _resetOrientation();
    super.dispose();
  }

  List<Group> _sortGroups(List<Group> groups) {
    final sorted = List<Group>.from(groups);
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  List<Camera> _sortCameras(List<Camera> cameras) {
    final sorted = List<Camera>.from(cameras);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  void _requestCamerasForGroup(String projectId, String groupId) {
    final key = '$projectId|$groupId';
    if (_requestedGroups.add(key)) {
      context.read<CameraBloc>().add(
        LoadCamerasByGroup(projectId: projectId, groupId: groupId),
      );
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!mounted) return;

    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {
        // App may not declare landscape orientations; ignore.
      }
    } else {
      _resetOrientation();
    }
  }

  void _resetOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (_) {
      // Ignore.
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _maybeJumpToCurrent(List<Camera> sequence) {
    final ids = sequence.map((c) => c.id).toList();
    final changed =
        ids.length != _lastSequenceIds.length ||
        !_listEquals(ids, _lastSequenceIds);

    if (!changed) return;

    _lastSequenceIds = ids;

    if (!_pageController.hasClients) return;

    final idx = sequence.indexWhere((c) => c.id == _currentCameraId);
    final target = idx >= 0 ? idx : 0;

    // Keep overlay + caching window in sync even if we programmatically jump.
    final targetId = sequence[target].id;
    if (mounted && (_currentCameraId != targetId || _currentIndex != target)) {
      setState(() {
        _currentCameraId = targetId;
        _currentIndex = target;
      });
    }

    final currentPage = (_pageController.page ?? 0).round();
    if (currentPage != target) {
      _pageController.jumpToPage(target);
    }
  }

  void _setInfoCollapsed(bool collapsed, {required bool allowAutoHide}) {
    if (!mounted) return;

    setState(() => _infoCollapsed = collapsed);

    _landscapeAutoHideTimer?.cancel();

    // Auto-hide only in landscape/fullscreen mode, and only when expanded.
    if (allowAutoHide && !collapsed) {
      _landscapeAutoHideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _infoCollapsed = true);
      });
    }
  }

  bool _shouldKeepAlivePage(int pageIndex) {
    // Cache window: keep only current, prev, next alive.
    return (pageIndex - _currentIndex).abs() <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final allowAutoHide = isLandscape || _isFullscreen;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: BlocBuilder<GroupBloc, GroupState>(
          builder: (context, groupState) {
            if (groupState is GroupError) {
              return Center(
                child: Text(
                  groupState.message,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (groupState is! GroupLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = _sortGroups(groupState.getGroups(widget.projectId));
            final loadingGroupsForProject = groupState.isLoadingProject(
              widget.projectId,
            );

            if (groups.isEmpty) {
              return Center(
                child: Text(
                  loadingGroupsForProject
                      ? "Loading groups…"
                      : "No groups found in this project.",
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              );
            }

            for (final g in groups) {
              _requestCamerasForGroup(widget.projectId, g.id);
            }

            final groupById = {for (final g in groups) g.id: g};

            return BlocBuilder<CameraBloc, CameraState>(
              builder: (context, camState) {
                final cameras = <Camera>[];

                if (camState is CameraLoaded) {
                  for (final g in groups) {
                    final list =
                        camState.grouped[widget.projectId]?[g.id] ??
                        const <Camera>[];
                    cameras.addAll(_sortCameras(list));
                  }
                }

                if (cameras.isEmpty) {
                  final anyLoading =
                      camState is CameraLoaded &&
                      groups.any(
                        (g) => camState.isLoadingGroup(widget.projectId, g.id),
                      );

                  return Center(
                    child: Text(
                      anyLoading
                          ? "Loading cameras…"
                          : "No cameras in this project yet.",
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _maybeJumpToCurrent(cameras);
                });

                return Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: cameras.length,
                      onPageChanged: (index) {
                        final cam = cameras[index];

                        if (!mounted) return;

                        // Keep overlay + caching window in sync.
                        setState(() {
                          _currentCameraId = cam.id;
                          _currentIndex = index;
                        });

                        // In landscape/fullscreen, show info briefly again after each swipe.
                        if (allowAutoHide) {
                          _setInfoCollapsed(
                            false,
                            allowAutoHide: allowAutoHide,
                          );
                        }
                      },
                      itemBuilder: (_, i) {
                        final cam = cameras[i];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // If the info chip is open, tapping anywhere hides it in BOTH orientations.
                            // We never "show on tap" (showing happens via the chip pill or dragging).
                            if (_infoCollapsed) return;
                            _setInfoCollapsed(
                              true,
                              allowAutoHide: allowAutoHide,
                            );
                          },
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _CameraPage(
                                key: ValueKey('camera-page-${cam.id}'),
                                camera: cam,
                                keepAlive: _shouldKeepAlivePage(i),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    Positioned(
                      top: 8,
                      left: 8,
                      child: SafeArea(
                        child: _BackButtonPill(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: SafeArea(
                        child: _CameraInfoOverlay(
                          currentCameraId: _currentCameraId,
                          cameras: cameras,
                          groupById: groupById,
                          collapsed: _infoCollapsed,
                          allowAutoHide: allowAutoHide,
                          onCollapse: () => _setInfoCollapsed(
                            true,
                            allowAutoHide: allowAutoHide,
                          ),
                          onExpand: () => _setInfoCollapsed(
                            false,
                            allowAutoHide: allowAutoHide,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: IconButton(
                        onPressed: _toggleFullscreen,
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        tooltip: _isFullscreen
                            ? "Exit Fullscreen"
                            : "Fullscreen",
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CameraPage extends StatefulWidget {
  final Camera camera;
  final bool keepAlive;

  const _CameraPage({super.key, required this.camera, required this.keepAlive});

  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage>
    with AutomaticKeepAliveClientMixin {
  VlcPlayerController? _controller;

  bool _loading = true;
  String? _error;

  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    _createController();

    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      if (_error == null && _loading) {
        setState(() {
          _error = "Still connecting…";
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }

    if (oldWidget.camera.id != widget.camera.id ||
        oldWidget.camera.rtspUrl != widget.camera.rtspUrl) {
      _recreateController();
    }
  }

  void _createController() {
    _controller = VlcPlayerController.network(
      widget.camera.rtspUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );

    _controller!.addListener(_onVlcChanged);

    _loading = true;
    _error = null;
  }

  void _recreateController() {
    final old = _controller;
    _controller = null;

    if (old != null) {
      old.removeListener(_onVlcChanged);
      _safeDisposeVlcController(old);
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _createController();
    setState(() {});
  }

  void _onVlcChanged() {
    final c = _controller;
    if (c == null || !mounted) return;

    final v = c.value;

    if (v.hasError) {
      final next = v.errorDescription?.trim().isNotEmpty == true
          ? v.errorDescription!.trim()
          : "Stream error";
      if (_error != next || !_loading) {
        setState(() {
          _error = next;
          _loading = false;
        });
      }
      return;
    }

    final isReady = v.isInitialized;
    final hasStarted = v.isPlaying || v.position.inMilliseconds > 0;

    final nextLoading = !(isReady && hasStarted);

    if (nextLoading != _loading || _error != null) {
      setState(() {
        _loading = nextLoading;
        _error = null;
      });
    }
  }

  void _retry() {
    _recreateController();
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _loadingTimeout = null;

    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onVlcChanged);
      _safeDisposeVlcController(c);
    }
    super.dispose();
  }

  void _safeDisposeVlcController(VlcPlayerController controller) {
    try {
      controller.dispose();
    } catch (e) {
      final msg = e.toString();
      final isKnownVlcLateInit =
          msg.contains("LateInitializationError") || msg.contains("_viewId");
      if (isKnownVlcLateInit) return;

      debugPrint('[CameraViewer] VLC dispose error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VlcPlayer(
          key: ValueKey('vlc-${widget.camera.id}'),
          controller: c,
          aspectRatio: 16 / 9,
          placeholder: const Center(child: CircularProgressIndicator()),
        ),
        if (_loading)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Connecting…", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        if (_error != null && !_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _retry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}

class _BackButtonPill extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButtonPill({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _CameraInfoOverlay extends StatelessWidget {
  final String currentCameraId;
  final List<Camera> cameras;
  final Map<String, Group> groupById;

  final bool collapsed;
  final bool allowAutoHide;
  final VoidCallback onCollapse;
  final VoidCallback onExpand;

  const _CameraInfoOverlay({
    required this.currentCameraId,
    required this.cameras,
    required this.groupById,
    required this.collapsed,
    required this.allowAutoHide,
    required this.onCollapse,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) return const SizedBox.shrink();

    final idx = cameras.indexWhere((c) => c.id == currentCameraId);
    final safeIdx = idx >= 0 ? idx : 0;

    final cam = cameras[safeIdx];
    final group = groupById[cam.groupId];

    final header = group?.name ?? "Group";
    final sub = cam.name;
    final count = '${safeIdx + 1}/${cameras.length}';

    if (collapsed) {
      return Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onVerticalDragUpdate: (d) {
            if (d.delta.dy > 6) onExpand();
          },
          onTap: onExpand,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Show info",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy < -6) onCollapse();
      },
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.videocam, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      header,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(count, style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onCollapse,
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white70,
                ),
                tooltip: "Hide info",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
