import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/billing.dart';
import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/prescriptions_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_messages.dart';
import 'login_screen.dart';
import 'specialist_monitoring_screen.dart';
import 'specialist_new_prescription_screen.dart';
import 'specialist_profile_edit_screen.dart';

class SpecialistHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const SpecialistHomeScreen({super.key, this.profile});

  @override
  State<SpecialistHomeScreen> createState() => _SpecialistHomeScreenState();
}

class _SpecialistHomeScreenState extends State<SpecialistHomeScreen> {
  bool _outOfService = true;
  final _session = SessionService();
  final _authApi = AuthApiService();
  final _consultationApi = ConsultationApiService();
  final _prescriptionsApi = PrescriptionsApiService();

  List<SpecialistConsultationDto> _consultations = [];
  List<PrescriptionSummaryDto> _prescriptions = [];
  Map<String, dynamic> _profile = {};
  bool _dashLoading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile != null
        ? Map<String, dynamic>.from(widget.profile!)
        : <String, dynamic>{};
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _dashLoading = true);
    try {
      final consults = await _consultationApi.fetchSpecialistConsultations(accessToken: token);
      final presc = await _prescriptionsApi.listSpecialist(accessToken: token);
      final prof = await _authApi.me(token);
      if (!mounted) return;
      setState(() {
        _consultations = consults;
        _prescriptions = presc;
        _profile = prof;
        _dashLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dashLoading = false);
    }
  }

  int get _distinctPatients {
    final ids = <String>{};
    for (final c in _consultations) {
      ids.add(c.patientUserId);
    }
    return ids.length;
  }

  String _ratingLabel() {
    final r = _profile['average_rating'];
    if (r == null) return '—';
    final n = r is num ? r.toDouble() : double.tryParse('$r');
    if (n == null) return '—';
    return n.toStringAsFixed(1);
  }

  Future<void> _openProfileEdit() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SpecialistProfileEditScreen(profile: _profile),
      ),
    );
    if (ok == true && mounted) await _loadDashboard();
  }

  Future<void> _logout() async {
    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile['first_name'] as String?) ?? '';
    final lastName = (_profile['last_name'] as String?) ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 14,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.navy, size: 18),
            const SizedBox(width: 6),
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
          TextButton.icon(
            onPressed: _openProfileEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryBlue),
            label: Text(
              'Perfil',
              style: GoogleFonts.inter(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 18, color: AppColors.demoText),
            label: Text(
              'Salir',
              style: GoogleFonts.inter(
                color: AppColors.demoText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                fullName.isEmpty ? 'Mi perfil' : 'Mi perfil - $fullName',
                style: GoogleFonts.inter(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _AvailabilityCard(
              isOutOfService: _outOfService,
              onChanged: (value) {
                setState(() => _outOfService = value);
                showFeatureMessage(
                  context,
                  title: value ? 'Fuera de servicio' : 'Disponible',
                  body: value
                      ? 'No recibirás nuevas asignaciones temporalmente.'
                      : 'Volverás a recibir nuevas asignaciones.',
                );
              },
            ),
            const SizedBox(height: 10),
            _PrescriptionCtaCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SpecialistNewPrescriptionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.85,
              children: [
                _MetricCard(
                  icon: Icons.calendar_today_outlined,
                  value: _dashLoading ? '…' : '${_consultations.length}',
                  label: 'Consultas asignadas',
                ),
                _MetricCard(
                  icon: Icons.group_outlined,
                  value: _dashLoading ? '…' : '$_distinctPatients',
                  label: 'Pacientes',
                ),
                _MetricCard(
                  icon: Icons.star_border_rounded,
                  value: _dashLoading ? '…' : _ratingLabel(),
                  label: 'Calificación media',
                ),
                _MetricCard(
                  icon: Icons.medication_outlined,
                  value: _dashLoading ? '…' : '${_prescriptions.length}',
                  label: 'Fórmulas',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SpecialistMonitoringScreen(),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_heart_outlined, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguimiento y remisiones',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              'Resultados, evolución, remisiones',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.demoText),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SpecialistPatientsFromConsultations(
              consultations: _consultations,
              loading: _dashLoading,
            ),
            const SizedBox(height: 12),
            _CommissionCard(
              onDetails: () => showFeatureMessage(
                context,
                title: 'Comisiones',
                body: 'Aquí verás el desglose de comisiones por consulta.',
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PrescriptionCtaCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PrescriptionCtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fórmulas y medicamentos',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registrar fórmula para un paciente',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool isOutOfService;
  final ValueChanged<bool> onChanged;

  const _AvailabilityCard({
    required this.isOutOfService,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C879A), Color(0xFF596377)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.power_settings_new, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutOfService ? 'Fuera de servicio' : 'Disponible',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOutOfService
                      ? 'No recibirás nuevas asignaciones hasta que te actives'
                      : 'Recibirás nuevas asignaciones de pacientes',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOutOfService,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF2D3748),
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primaryBlue),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.demoText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialistPatientsFromConsultations extends StatelessWidget {
  final List<SpecialistConsultationDto> consultations;
  final bool loading;

  const _SpecialistPatientsFromConsultations({
    required this.consultations,
    required this.loading,
  });

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '??';
    if (p.length == 1) {
      final s = p[0];
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return '${p[0][0]}${p[p.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (consultations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'Aún no tienes consultas asignadas. Las nuevas solicitudes aparecerán aquí.',
          style: GoogleFonts.inter(color: AppColors.demoText, height: 1.35),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE9F0FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6BFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_outlined, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes asignados',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        '${consultations.length} consultas recientes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.demoText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final c in consultations.take(8))
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                      child: Text(
                        _initials(c.patientDisplayName),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      c.patientDisplayName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${c.specialty} · ${c.scheduledAt ?? "sin cita programada"}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                    ),
                    trailing: c.patientRating != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                              Text(
                                '${c.patientRating}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                            ],
                          )
                        : null,
                    onTap: () => showFeatureMessage(
                      context,
                      title: 'Consulta',
                      body: c.description.isNotEmpty ? c.description : 'Sin descripción adicional.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final VoidCallback onDetails;

  const _CommissionCard({required this.onDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comisión de plataforma: $kPlatformCommissionPercent%',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Por cada consulta cobrada, recibes el $kSpecialistSharePercent% neto; MediConnect retiene el $kPlatformCommissionPercent%.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: onDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF166534),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Ver detalles',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
