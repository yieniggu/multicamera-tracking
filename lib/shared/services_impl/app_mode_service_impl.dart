import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';

class AppModeServiceImpl implements AppMode {
  bool _isRemote = false;

  @override
  bool get isRemote => _isRemote;

  @override
  bool get isGuest => !_isRemote;

  @override
  bool get isTrial => !_isRemote;

  @override
  void enterGuest() => _isRemote = false;

  @override
  void enterRemote() => _isRemote = true;
}
