import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/register_screen.dart';

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
    setState(() => hideGuestButton = isGuest);
  }

  void _loginWithEmail() {
    context.read<AuthBloc>().add(
      AuthSignedInWithEmail(emailCtrl.text.trim(), passCtrl.text.trim()),
    );
  }

  void _loginAsGuest() {
    context.read<AuthBloc>().add(AuthSignedInAnonymously());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          // Navigate to AuthGate (triggers repository reinit + HomeScreen)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
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
              ElevatedButton(
                onPressed: _loginWithEmail,
                child: const Text("Login"),
              ),
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
                  onPressed: _loginAsGuest,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
