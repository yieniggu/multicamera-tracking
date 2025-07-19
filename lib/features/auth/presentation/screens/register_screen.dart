import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';

import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/config/di.dart';

import 'auth_gate.dart';

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

  bool hasGuestData = false;
  bool migrateGuestData = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[REGSITER-SCREEN] Init register screen state");
    _checkGuestData();
  }

  Future<void> _checkGuestData() async {
    debugPrint("[REGISTER-SCREEN] Checking guest data");

    // Bypass repo, use Hive directly to avoid user check
    final localProjectDataSource = getIt<ProjectLocalDatasource>();
    final projects = await localProjectDataSource.getAll("guest");

    final exists = projects.isNotEmpty;
    setState(() => hasGuestData = exists);
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthRegisteredWithEmail(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        shouldMigrateGuestData: hasGuestData && migrateGuestData,
      ),
    );
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
    debugPrint("[REGSITER-SCREEN] Build register screen");

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => isLoading = true);
        } else {
          setState(() => isLoading = false);
        }

        if (state is AuthAuthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
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
                          if (value == null || value.isEmpty) {
                            return "Email required";
                          }
                          if (!value.contains('@')) {
                            return "Invalid email";
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                        ),
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
                          if (value != passCtrl.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                      if (hasGuestData)
                        CheckboxListTile(
                          contentPadding: const EdgeInsets.only(top: 12),
                          title: const Text("Migrate data from guest session"),
                          value: migrateGuestData,
                          onChanged: (value) {
                            setState(() => migrateGuestData = value ?? true);
                          },
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isLoading ? null : _submitRegistration,
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
      ),
    );
  }
}
