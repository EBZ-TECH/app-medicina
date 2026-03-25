import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'login_screen.dart';

class SpecialistHomeScreen extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const SpecialistHomeScreen({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    final firstName = (profile?['first_name'] as String?) ?? '';
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MediConnect',
          style: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido, Especialista${firstName.isNotEmpty ? ' - $firstName' : ''}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Esta pantalla se completará cuando conectemos las funciones del especialista.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.demoText,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryBlue),
                ),
                child: Text(
                  'Volver al login',
                  style: GoogleFonts.inter(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

