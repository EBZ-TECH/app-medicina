import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/payment_plans.dart';
import '../services/appointment_reminder_service.dart';
import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_messages.dart';
import 'login_screen.dart';
import 'patient_consultations_screen.dart';
import 'patient_medications_screen.dart';
import 'patient_monitoring_screen.dart';
import 'request_consultation_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const PatientHomeScreen({super.key, this.profile});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _authApi = AuthApiService();
  final _consultationApi = ConsultationApiService();
  late Map<String, dynamic> _profile;
  bool _planBusy = false;

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
      /* sin recordatorios si falla la API */
    } catch (_) {}
  }

  String get _paymentPlanCode =>
      (_profile['payment_plan'] as String?) ?? kPaymentPlanPayPerConsult;

  Future<void> _refreshProfile() async {
    final token = await SessionService().getAccessToken();
    if (token == null || !mounted) return;
    try {
      final p = await _authApi.me(token);
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (_) {
      /* mantiene perfil previo */
    }
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
                      backgroundColor: const Color(0xFF2563EB),
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
      setState(() => _profile = updated);
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

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile['first_name'] as String?) ?? '';
    final role = (_profile['role'] as String?) ?? 'Paciente';

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
            const Icon(Icons.favorite, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Text(
              'MediConnect',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SessionService().clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                firstName.isEmpty
                    ? 'Bienvenido, $role'
                    : 'Bienvenido, $role - $firstName',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.82,
              children: [
                _ActionTile(
                  color: const Color(0xFF2563EB),
                  icon: Icons.calendar_today_rounded,
                  label: 'Solicitar consulta',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RequestConsultationScreen(),
                      ),
                    );
                  },
                ),
                _ActionTile(
                  color: const Color(0xFF16A34A),
                  icon: Icons.monitor_heart_outlined,
                  label: 'Ver seguimiento',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PatientMonitoringScreen(),
                      ),
                    );
                  },
                ),
                _ActionTile(
                  color: const Color(0xFF7C3AED),
                  icon: Icons.medication_outlined,
                  label: 'Medicamentos',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PatientMedicationsScreen(),
                      ),
                    );
                  },
                ),
                _ActionTile(
                  color: const Color(0xFFF97316),
                  icon: Icons.calendar_month_rounded,
                  label: 'Próximas consultas',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PatientConsultationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Próximas consultas',
              subtitle: '2 consultas programadas',
              headerColor: const Color(0xFFDCE8F8),
              leadingColor: const Color(0xFF2563EB),
              leadingIcon: Icons.calendar_today_rounded,
              child: Column(
                children: [
                  _AppointmentCard(
                    initials: 'DM',
                    name: 'Dr. María González',
                    specialty: 'Fisioterapia',
                    date: '2026-03-25',
                    hour: '10:00 AM',
                    status: 'Confirmada',
                    statusColor: const Color(0xFF22C55E),
                    showMapButton: true,
                    onMapPressed: () => showFeatureMessage(
                      context,
                      title: 'Mapa del especialista',
                      body:
                          'Se mostrará la ubicación del consultorio en el mapa.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AppointmentCard(
                    initials: 'DC',
                    name: 'Dr. Carlos Ramírez',
                    specialty: 'Medicina general',
                    date: '2026-03-28',
                    hour: '3:00 PM',
                    status: 'Pendiente',
                    statusColor: const Color(0xFFEAB308),
                    showMapButton: false,
                    onMapPressed: () => showFeatureMessage(
                      context,
                      title: 'Mapa del especialista',
                      body:
                          'Se mostrará la ubicación del consultorio en el mapa.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Resultados recientes',
              subtitle: '2 resultados disponibles',
              headerColor: const Color(0xFFDDF3E5),
              leadingColor: const Color(0xFF16A34A),
              leadingIcon: Icons.assignment_outlined,
              child: Column(
                children: [
                  _ResultRow(
                    title: 'Evaluación de fisioterapia',
                    doctor: 'Dr. María González',
                    date: '2026-03-15',
                    iconColor: const Color(0xFF16A34A),
                    icon: Icons.description_outlined,
                    onTap: () => showFeatureMessage(
                      context,
                      title: 'Resultado',
                      body: 'Vista detallada del informe y archivos adjuntos.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ResultRow(
                    title: 'Consulta psicológica',
                    doctor: 'Dra. Ana Martínez',
                    date: '2026-03-10',
                    iconColor: const Color(0xFF16A34A),
                    icon: Icons.description_outlined,
                    onTap: () => showFeatureMessage(
                      context,
                      title: 'Resultado',
                      body: 'Vista detallada del informe y archivos adjuntos.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan actual: ${paymentPlanLabel(_paymentPlanCode)}',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              paymentPlanSubtitleForCard(_paymentPlanCode),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _planBusy ? null : _openPaymentPlanSheet,
                      child: _planBusy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF2563EB),
                              ),
                            )
                          : Text(
                              'Actualizar plan',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
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

class _ActionTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.90), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color headerColor;
  final Color leadingColor;
  final IconData leadingIcon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.headerColor,
    required this.leadingColor,
    required this.leadingIcon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(leadingIcon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.demoText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String initials;
  final String name;
  final String specialty;
  final String date;
  final String hour;
  final String status;
  final Color statusColor;
  final bool showMapButton;
  final VoidCallback onMapPressed;
  const _AppointmentCard({
    required this.initials,
    required this.name,
    required this.specialty,
    required this.date,
    required this.hour,
    required this.status,
    required this.statusColor,
    this.showMapButton = true,
    required this.onMapPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      specialty,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.demoText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.demoText),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time, size: 14, color: AppColors.demoText),
                        const SizedBox(width: 4),
                        Text(
                          hour,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (showMapButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onMapPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Ver especialista en mapa',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String title;
  final String doctor;
  final String date;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _ResultRow({
    required this.title,
    required this.doctor,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E8EE)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.demoText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.demoText),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.demoText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.hintGrey),
          ],
        ),
      ),
    );
  }
}

