import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'register_screen.dart';
import 'patient_home_screen.dart';
import 'specialist_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authApi = AuthApiService();
  final _session = SessionService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppColors.hintGrey, fontSize: 15),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce tu correo electrónico')),
      );
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce tu contraseña')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final login = await _authApi.login(
        email: email,
        password: _passwordController.text,
      );
      await _session.saveTokens(
        accessToken: login.accessToken,
        refreshToken: login.refreshToken,
      );

      final profileRaw = await _authApi.me(login.accessToken);
      final profile = Map<String, dynamic>.from(profileRaw);
      final em = profile['email'] as String?;
      if (em == null || em.isEmpty) {
        profile['email'] = email;
      }
      final role = (profile['role'] as String?) ?? 'Usuario';

      if (!mounted) return;
      if (role == 'Paciente') {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PatientHomeScreen(profile: profile),
          ),
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SpecialistHomeScreen(profile: profile),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible iniciar sesión')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
  }

  void _onRegisterTap() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: AppColors.primaryBlue,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'MediConnect',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Iniciar sesión',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Correo electrónico',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.labelGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                        decoration: _fieldDecoration(
                          hint: 'tu@email.com',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: AppColors.hintGrey,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Contraseña',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.labelGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onLogin(),
                        style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                        decoration: _fieldDecoration(
                          hint: '••••••••',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.hintGrey,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Iniciar sesión',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta? ',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.demoText,
                            ),
                          ),
                          TextButton(
                            onPressed: _onRegisterTap,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Regístrate aquí',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.demoBoxBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tu rol (Paciente o Especialista) lo defines al '
                          'registrarte. Si aún no tienes cuenta, pulsa '
                          '«Regístrate aquí».',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.demoText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
