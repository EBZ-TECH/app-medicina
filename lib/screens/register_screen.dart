import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/specialties.dart';
import '../services/auth_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'patient_home_screen.dart';
import 'specialist_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authApi = AuthApiService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _professionalTitleController = TextEditingController();

  bool _isPatient = true;
  String? _selectedSpecialty;
  String? _professionalCardFileName;
  PlatformFile? _professionalCardFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _professionalTitleController.dispose();
    super.dispose();
  }

  InputDecoration _outlineDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
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

  Future<void> _pickAgeFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    var age = now.year - picked.year;
    if (now.month < picked.month ||
        (now.month == picked.month && now.day < picked.day)) {
      age--;
    }
    setState(() => _ageController.text = '$age');
  }

  Future<void> _pickProfessionalCard() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() {
      _professionalCardFile = file;
      _professionalCardFileName = file.name;
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y apellido')),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce tu correo electrónico')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
        ),
      );
      return;
    }
    final ageStr = _ageController.text.trim();
    final ageInt = int.tryParse(ageStr);
    if (ageStr.isEmpty || ageInt == null || ageInt < 1 || ageInt > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica una edad válida (entre 1 y 120 años)'),
        ),
      );
      return;
    }
    final phoneStr = _phoneController.text.trim();
    if (!_isValidPhone(phoneStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica un número de celular válido (mín. 8 caracteres y 7 dígitos)'),
        ),
      );
      return;
    }
    if (!_isPatient) {
      if (_professionalTitleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica tu título profesional')),
        );
        return;
      }
      if (_selectedSpecialty == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una especialidad')),
        );
        return;
      }
      if (_professionalCardFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjunta tu tarjeta profesional (imagen o PDF)'),
          ),
        );
        return;
      }
    }

    final role = _isPatient ? 'Paciente' : 'Especialista';
    setState(() => _isSubmitting = true);
    try {
      final login = await _authApi.register(
        RegisterPayload(
          role: role,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          age: ageStr,
          phone: phoneStr,
          email: email,
          password: _passwordController.text,
          professionalTitle: _isPatient ? null : _professionalTitleController.text.trim(),
          specialty: _isPatient ? null : _selectedSpecialty,
          professionalCard: _isPatient ? null : _professionalCardFile,
        ),
      );

      await SessionService().saveTokens(
        accessToken: login.accessToken,
        refreshToken: login.refreshToken,
      );

      final profileRaw = await _authApi.me(login.accessToken);
      final profile = Map<String, dynamic>.from(profileRaw);
      final em = profile['email'] as String?;
      if (em == null || em.isEmpty) {
        profile['email'] = email;
      }

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
        const SnackBar(content: Text('No fue posible crear la cuenta')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _fieldLabel(String text, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        required ? '$text *' : text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.labelGrey,
        ),
      ),
    );
  }

  bool _isValidPhone(String raw) {
    final s = raw.trim();
    if (s.length < 8) return false;
    final digitsOnly = s.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 7;
  }

  Widget _userTypeOption({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: selected ? AppColors.demoBoxBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryBlue,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
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
                    const SizedBox(height: 20),
                    Text(
                      'Crear cuenta',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los campos marcados con * son obligatorios.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.hintGrey,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tipo de usuario *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.labelGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _userTypeOption(
                          selected: _isPatient,
                          label: 'Paciente',
                          onTap: () => setState(() => _isPatient = true),
                        ),
                        _userTypeOption(
                          selected: !_isPatient,
                          label: 'Especialista',
                          onTap: () => setState(() => _isPatient = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _fieldLabel('Nombre'),
                    TextField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(hintText: 'Tu nombre'),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Apellido'),
                    TextField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(hintText: 'Tu apellido'),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Edad'),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(
                        hintText: 'Ej. 25',
                        prefixIcon: IconButton(
                          icon: Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.hintGrey,
                            size: 22,
                          ),
                          onPressed: _pickAgeFromCalendar,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Número de celular'),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(
                        hintText: '+57 300 000 0000',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColors.hintGrey,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Correo electrónico'),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(
                        hintText: 'tu@email.com',
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.hintGrey,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Contraseña'),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.navy),
                      decoration: _outlineDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.hintGrey,
                          size: 22,
                        ),
                      ),
                    ),
                    if (!_isPatient) ...[
                      const SizedBox(height: 28),
                      Divider(height: 1, color: AppColors.borderGrey),
                      const SizedBox(height: 22),
                      Text(
                        'Información profesional',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Título profesional'),
                      TextField(
                        controller: _professionalTitleController,
                        textCapitalization: TextCapitalization.sentences,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.navy,
                        ),
                        decoration: _outlineDecoration(
                          hintText: 'Ej. Médico cirujano',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Tarjeta profesional (imagen)'),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _pickProfessionalCard,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderGrey),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.upload_outlined,
                                  color: AppColors.hintGrey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _professionalCardFileName == null
                                        ? 'Elegir archivo — No se ha seleccionado ningún archivo'
                                        : _professionalCardFileName!,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _professionalCardFileName == null
                                          ? AppColors.hintGrey
                                          : AppColors.navy,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Tipo de especialista'),
                      InputDecorator(
                        decoration: _outlineDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSpecialty,
                            isExpanded: true,
                            hint: Text(
                              'Selecciona una especialidad',
                              style: GoogleFonts.inter(
                                color: AppColors.hintGrey,
                                fontSize: 15,
                              ),
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.hintGrey,
                            ),
                            items: kMedicalSpecialties
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: GoogleFonts.inter(
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSpecialty = v),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
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
                                'Crear cuenta',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
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
    );
  }
}
