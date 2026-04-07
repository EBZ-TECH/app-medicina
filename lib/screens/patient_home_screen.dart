import 'package:flutter/material.dart';

import 'patient_shell_screen.dart';

/// Punto de entrada histórico: ahora el paciente usa shell con barra inferior Inicio | Perfil.
class PatientHomeScreen extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const PatientHomeScreen({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    return PatientShellScreen(profile: profile);
  }
}
