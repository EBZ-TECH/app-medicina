import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'patient_home_screen.dart';
import 'specialist_home_screen.dart';

/// Decide la pantalla inicial: sesión válida → home según rol; si no, login.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  final _session = SessionService();
  final _authApi = AuthApiService();
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _session.getAccessToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _child = const LoginScreen());
      return;
    }

    try {
      final profile = await _authApi.me(token);
      final role = profile['role'] as String? ?? 'Paciente';
      if (!mounted) return;
      setState(() {
        _child = role == 'Paciente'
            ? PatientHomeScreen(profile: profile)
            : SpecialistHomeScreen(profile: profile);
      });
    } catch (_) {
      await _session.clear();
      if (!mounted) return;
      setState(() => _child = const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _child ??
        const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
  }
}
