import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/presentation/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multicamera_tracking/presentation/screens/auth_gate.dart';

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
    final repo = getIt<AuthRepository>();
    try {
      await repo.signInWithEmail(emailCtrl.text.trim(), passCtrl.text.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false); // reset guest flag if needed
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  Future<void> _signInAsGuest() async {
    final repo = getIt<AuthRepository>();
    try {
      await repo.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', true);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Guest login failed: $e")));
    }
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
