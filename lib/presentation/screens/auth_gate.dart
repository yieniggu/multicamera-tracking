import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/application/providers/project_manager.dart';
import 'package:multicamera_tracking/presentation/screens/home_screen.dart';
import 'package:multicamera_tracking/presentation/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isGuestFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_guest') ?? false;
  }

  Future<(Widget screen, String userId)> _resolveHomeOrLogin() async {
    final authRepo = getIt<AuthRepository>();
    final user = authRepo.currentUser;

    if (user == null) return (const LoginScreen(), "");

    final isGuest = user.isAnonymous && await _isGuestFlag();

    try {
      // 🔧 Configure the correct repository implementations
      await configureRepositories(user);

      // 💾 Ensure default project/group
      if (getIt.isRegistered<InitUserDataService>()) {
        getIt.unregister<InitUserDataService>();
      }
      getIt.registerSingleton<InitUserDataService>(
        InitUserDataServiceImpl(
          projectRepository: getIt<ProjectRepository>(),
          groupRepository: getIt<GroupRepository>(),
        ),
      );
      await getIt<InitUserDataService>().ensureDefaultProjectAndGroup(user.id);

      return (HomeScreen(isGuest: isGuest), user.id);
    } catch (e, st) {
      debugPrint("[AUTH-GATE] Error: $e");
      debugPrint("📄 StackTrace: $st");
      return (const LoginScreen(), "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Widget, String)>(
      future: _resolveHomeOrLogin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final (screen, userId) = snapshot.data!;

        if (screen is HomeScreen) {
          return ChangeNotifierProvider<ProjectManager>(
            key: ValueKey(userId), // ensures fresh instance per user
            create: (_) => ProjectManager()..loadAll(),
            child: screen,
          );
        }

        return screen;
      },
    );
  }
}
