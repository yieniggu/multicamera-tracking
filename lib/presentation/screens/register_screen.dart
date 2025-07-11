import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_project_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';

import 'package:multicamera_tracking/data/services_impl/guest_data_service_impl.dart';
import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/data/services_impl/migrate_user_data_service_impl.dart';

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
  bool hasGuestData = false;
  bool migrateGuestData = true;

  @override
  void initState() {
    super.initState();
    _checkGuestData();
  }

  Future<void> _checkGuestData() async {
    if (!getIt.isRegistered<GuestDataService>()) {
      final projectBox = await Hive.openBox<ProjectModel>('projects');
      final groupBox = await Hive.openBox<GroupModel>('groups');

      final hiveProjectRepo = HiveProjectRepository(box: projectBox);
      final hiveGroupRepo = HiveGroupRepository(box: groupBox);

      getIt.registerSingleton<GuestDataService>(
        GuestDataService(
          projectRepository: hiveProjectRepo,
          groupRepository: hiveGroupRepo,
        ),
      );
    }

    final guestDataService = getIt<GuestDataService>();
    final exists = await guestDataService.hasDataToMigrate();
    setState(() {
      hasGuestData = exists;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = getIt<AuthRepository>();
    setState(() => isLoading = true);

    try {
      final user = await authRepo.registerWithEmail(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );
      if (user == null) throw Exception("User is null after registration");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);

      await _setupUserContext(user.id);

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("[REGISTER-SCREEN] Error on register: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Registration failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _setupUserContext(String userId) async {
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

    final initializer = getIt<InitUserDataService>();

    if (!hasGuestData) {
      await initializer.ensureDefaultProjectAndGroup(userId);
    } else if (migrateGuestData) {
      debugPrint("[REGISTER] Migrating guest data to Firestore");
      await migrateGuestDataToFirestore(userId);
    } else {
      debugPrint(
        "[REGISTER] Skipping migration, creating default project/group",
      );
      await initializer.ensureDefaultProjectAndGroup(userId);
    }

    // ✅ Refresh the existing ProjectManager from Provider
    // final manager = context.read<ProjectManager>();
    // await manager.loadAll();
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
