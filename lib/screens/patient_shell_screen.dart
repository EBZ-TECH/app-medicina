import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../constants/payment_plans.dart';
import '../services/appointment_reminder_service.dart';
import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'patient_home_tab_content.dart';
import 'patient_profile_screen.dart';

/// Shell del paciente: barra inferior **Inicio | Perfil** (alineado con diseño Figma).
class PatientShellScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const PatientShellScreen({super.key, this.profile});

  @override
  State<PatientShellScreen> createState() => _PatientShellScreenState();
}

class _PatientShellScreenState extends State<PatientShellScreen> {
  final _authApi = AuthApiService();
  final _consultationApi = ConsultationApiService();

  int _tabIndex = 0;
  late Map<String, dynamic> _profile;
  bool _planBusy = false;
  bool _profileBusy = false;

  static const Color _navBlue = Color(0xFF2563EB);
  static const Color _navMuted = Color(0xFF7A8794);

  @override
  void initState() {
    super.initState();
    _profile = widget.profile != null
        ? Map<String, dynamic>.from(widget.profile!)
        : <String, dynamic>{};
    _refreshProfile();
    _loadConsultationsAndReminders();
  }

  Future<void> _loadConsultationsAndReminders() async {
    final token = await SessionService().getAccessToken();
    if (token == null || !mounted) return;
    try {
      final list = await _consultationApi.fetchPatientConsultations(accessToken: token);
      if (!mounted) return;
      await AppointmentReminderService.instance.syncFromConsultations(list);
    } on ApiException catch (_) {
    } catch (_) {}
  }

  String get _paymentPlanCode =>
      (_profile['payment_plan'] as String?) ?? kPaymentPlanPayPerConsult;

  Future<void> _refreshProfile() async {
    final token = await SessionService().getAccessToken();
    if (token == null || !mounted) return;
    try {
      final p = await _authApi.me(token);
      if (!mounted) return;
      final preservedEmail = _profile['email'];
      setState(() {
        _profile = p;
        if (preservedEmail != null &&
            preservedEmail is String &&
            preservedEmail.isNotEmpty &&
            (_profile['email'] == null || ('${_profile['email']}'.isEmpty))) {
          _profile = Map<String, dynamic>.from(_profile)..['email'] = preservedEmail;
        }
      });
    } on ApiException catch (_) {}
  }

  Future<void> _openPaymentPlanSheet() async {
    final token = await SessionService().getAccessToken();
    if (token == null || !mounted) return;
    var selected = _paymentPlanCode;

    final newPlan = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Modalidad de pago',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elige cómo prefieres pagar tus consultas en MediConnect.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  _PaymentModeTile(
                    title: 'Pago por consulta',
                    subtitle: 'Pagas solo cuando solicitas una consulta.',
                    selected: selected == kPaymentPlanPayPerConsult,
                    onTap: () => setModal(() => selected = kPaymentPlanPayPerConsult),
                  ),
                  const SizedBox(height: 8),
                  _PaymentModeTile(
                    title: 'Suscripción mensual',
                    subtitle: 'Acceso mensual según condiciones del plan.',
                    selected: selected == kPaymentPlanMonthly,
                    onTap: () => setModal(() => selected = kPaymentPlanMonthly),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Guardar', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (newPlan == null || !mounted) return;
    if (newPlan == _paymentPlanCode) return;

    setState(() => _planBusy = true);
    try {
      final updated = await _authApi.patchPaymentPlan(accessToken: token, paymentPlan: newPlan);
      if (!mounted) return;
      final preservedEmail = _profile['email'];
      setState(() {
        _profile = updated;
        if (preservedEmail != null &&
            preservedEmail is String &&
            preservedEmail.isNotEmpty &&
            (_profile['email'] == null || ('${_profile['email']}'.isEmpty))) {
          _profile = Map<String, dynamic>.from(_profile)..['email'] = preservedEmail;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan de pago actualizado')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _planBusy = false);
    }
  }

  Future<void> _logout() async {
    await SessionService().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  String? get _profilePhotoUrl {
    final rel = (_profile['profile_photo_path'] as String?)?.trim();
    if (rel == null || rel.isEmpty) return null;
    if (rel.startsWith('http://') || rel.startsWith('https://')) return rel;
    return '${AppConfig.apiBaseUrl}/uploads/$rel';
  }

  Future<void> _openPatientProfileEditor() async {
    final token = await SessionService().getAccessToken();
    if (token == null || !mounted) return;

    final phoneController = TextEditingController(
      text: ((_profile['phone'] as String?) ?? '').trim(),
    );
    PlatformFile? pickedPhoto;
    String pickedPhotoName = '';

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Editar perfil',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Número de celular',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                        withData: false,
                      );
                      if (picked == null || picked.files.isEmpty) return;
                      setModal(() {
                        pickedPhoto = picked.files.first;
                        pickedPhotoName = pickedPhoto?.name ?? '';
                      });
                    },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      pickedPhotoName.isEmpty ? 'Seleccionar foto de perfil' : pickedPhotoName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: _navBlue),
                    child: const Text('Guardar cambios'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) return;

    final newPhone = phoneController.text.trim();
    final digits = newPhone.replaceAll(RegExp(r'\D'), '');
    if (newPhone.length < 8 || digits.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica un número de celular válido')),
      );
      return;
    }

    setState(() => _profileBusy = true);
    try {
      final updated = await _authApi.patchPatientPublic(
        accessToken: token,
        phone: newPhone,
        profilePhoto: pickedPhoto,
      );
      if (!mounted) return;
      final preservedEmail = _profile['email'];
      setState(() {
        _profile = updated;
        if (preservedEmail != null &&
            preservedEmail is String &&
            preservedEmail.isNotEmpty &&
            (_profile['email'] == null || ('${_profile['email']}'.isEmpty))) {
          _profile = Map<String, dynamic>.from(_profile)..['email'] = preservedEmail;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _profileBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: _navBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tabIndex == 0 ? 'MediConnect' : 'Mi perfil',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _logout,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Salir',
                  style: GoogleFonts.inter(
                    color: AppColors.demoText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.demoText),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        sizing: StackFit.expand,
        children: [
          PatientHomeTabContent(
            profile: _profile,
            planBusy: _planBusy,
            onOpenPaymentPlan: _openPaymentPlanSheet,
          ),
          PatientProfileScreen(
            profile: _profile,
            planBusy: _planBusy,
            profileBusy: _profileBusy,
            profilePhotoUrl: _profilePhotoUrl,
            onEditProfile: _openPatientProfileEditor,
            onOpenPaymentPlan: _openPaymentPlanSheet,
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: BottomNavigationBar(
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: _navBlue,
              unselectedItemColor: _navMuted,
              selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? const Color(0xFF2563EB) : AppColors.hintGrey,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
