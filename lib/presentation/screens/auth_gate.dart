import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/presentation/screens/home_screen.dart';
import 'package:multicamera_tracking/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isGuestFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_guest') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = getIt<AuthRepository>();

    return StreamBuilder<AuthUser?>(
      stream: authRepo.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _isGuestFlag(),
            builder: (context, guestSnapshot) {
              if (!guestSnapshot.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final isGuest = snapshot.data!.isAnonymous && guestSnapshot.data!;
              return HomeScreen(isGuest: isGuest);
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
