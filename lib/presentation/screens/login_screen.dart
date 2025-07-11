import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/presentation/screens/register_screen.dart';
import 'package:multicamera_tracking/presentation/screens/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool hideGuestButton = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyGuest();
  }

  Future<void> _checkIfAlreadyGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('is_guest') ?? false;
    setState(() {
      hideGuestButton = isGuest;
    });
  }

  Future<void> _signIn() async {
    final authRepo = getIt<AuthRepository>();
    try {
      final user = await authRepo.signInWithEmail(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      if (user == null) throw Exception("User is null after sign-in");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);

      await _setupUserContext(user.id, isGuest: false);

      // ✅ Now restart the widget tree so AuthGate triggers and loads everything
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  Future<void> _signInAsGuest() async {
    final repo = getIt<AuthRepository>();
    try {
      final user = await repo.signInAnonymously();
      if (user == null) throw Exception("User is null after anonymous login");

      await _setupUserContext(user.id, isGuest: true);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Guest login failed: $e")));
    }
  }

  Future<void> _setupUserContext(String userId, {bool isGuest = false}) async {
    await configureRepositories(getIt<AuthRepository>().currentUser!);

    if (getIt.isRegistered<InitUserDataService>()) {
      getIt.unregister<InitUserDataService>();
    }

    getIt.registerSingleton<InitUserDataService>(
      InitUserDataServiceImpl(
        projectRepository: getIt<ProjectRepository>(),
        groupRepository: getIt<GroupRepository>(),
      ),
    );

    await getIt<InitUserDataService>().ensureDefaultProjectAndGroup(userId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', isGuest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _signIn, child: const Text("Login")),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text("Don't have an account? Register"),
            ),
            if (!hideGuestButton)
              TextButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text("Enter as Guest"),
                onPressed: _signInAsGuest,
              ),
          ],
        ),
      ),
    );
  }
}
