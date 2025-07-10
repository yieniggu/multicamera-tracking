import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/presentation/screens/home_screen.dart';
import 'package:multicamera_tracking/presentation/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isGuestFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_guest') ?? false;
  }

  Future<Widget> _resolveHomeOrLogin() async {
    final authRepo = getIt<AuthRepository>();
    final user = authRepo.currentUser;

    debugPrint("[AUTH-GATE] currentUser = ${user.toString()}");

    if (user == null) {
      debugPrint("[AUTH-GATE] No user found → LoginScreen");
      return const LoginScreen();
    }

    final isGuest = user.isAnonymous && await _isGuestFlag();
    debugPrint("👤 isGuest = $isGuest");

    try {
      debugPrint("[AUTH-GATE] Configuring repositories...");
      await configureRepositories(user);
      debugPrint("[AUTH-GATE] Repositories configured.");

      // Ensure InitUserDataService is registered
      if (getIt.isRegistered<InitUserDataService>()) {
        getIt.unregister<InitUserDataService>();
      }

      getIt.registerSingleton<InitUserDataService>(
        InitUserDataServiceImpl(
          projectRepository: getIt<ProjectRepository>(),
          groupRepository: getIt<GroupRepository>(),
        ),
      );

      // Ensure default project and group are initialized
      await getIt<InitUserDataService>().ensureDefaultProjectAndGroup(user.id);
    } catch (e, st) {
      debugPrint("[AUTH-GATE] Error during repository configuration: $e");
      debugPrint("[AUTH-GATE] StackTrace: $st");
      return const LoginScreen(); // fallback
    }

    return HomeScreen(isGuest: isGuest);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveHomeOrLogin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
