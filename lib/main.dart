import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/auth_gate.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("[MAIN] Triggering init dependencies...");
  await initDependencies();

  final authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());

  runApp(MyApp(authBloc: authBloc));
}

class MyApp extends StatelessWidget {
  final AuthBloc authBloc;

  const MyApp({super.key, required this.authBloc});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc), // Reuse instance
        BlocProvider(create: (_) => getIt<ProjectBloc>()),
        BlocProvider(create: (_) => getIt<GroupBloc>()),
        BlocProvider(create: (_) => getIt<CameraBloc>()),
      ],
      child: MaterialApp(
        title: 'Multi Camera Viewer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
