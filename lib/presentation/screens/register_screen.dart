import 'package:flutter/material.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/presentation/screens/auth_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = getIt<AuthRepository>();
    setState(() => isLoading = true);

    try {
      await repo.registerWithEmail(emailCtrl.text.trim(), passCtrl.text.trim());

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Registration failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Create Account",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: "Email"),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "Email required";
                        if (!value.contains('@')) return "Invalid email";
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm Password",
                      ),
                      validator: (value) {
                        if (value != passCtrl.text)
                          return "Passwords do not match";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isLoading ? null : _register,
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Create Account"),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Already have an account? Log in"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
