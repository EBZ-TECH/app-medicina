import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api_service.dart';
import '../services/prescriptions_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'patient_prescription_detail_screen.dart';

/// Panel 1.5: fórmulas, compra simulada, envío y mapa (detalle).
class PatientMedicationsScreen extends StatefulWidget {
  const PatientMedicationsScreen({super.key});

  @override
  State<PatientMedicationsScreen> createState() => _PatientMedicationsScreenState();
}

class _PatientMedicationsScreenState extends State<PatientMedicationsScreen> {
  final _api = PrescriptionsApiService();
  final _session = SessionService();

  List<PrescriptionSummaryDto> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _session.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sesión no válida';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listPatient(accessToken: token);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Medicamentos',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: GoogleFonts.inter(color: Colors.red[800])),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.medication_outlined, size: 56, color: AppColors.demoText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes fórmulas registradas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.demoText, height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _items[i];
        return _PrescriptionCard(
          p: p,
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => PatientPrescriptionDetailScreen(prescriptionId: p.id),
              ),
            );
            if (mounted) _load();
          },
        );
      },
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final PrescriptionSummaryDto p;
  final VoidCallback onTap;

  const _PrescriptionCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_outlined, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        if (p.specialistDisplayName != null && p.specialistDisplayName!.isNotEmpty)
                          Text(
                            p.specialistDisplayName!,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.hintGrey),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatusChip(status: p.status),
                  const Spacer(),
                  Text(
                    'COP ${_formatCop(p.estimatedTotalCents)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCop(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _label(status);
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  static String _label(String s) {
    switch (s) {
      case 'pending_payment':
        return 'Pendiente de pago';
      case 'paid':
        return 'Pagado';
      case 'shipping':
        return 'En envío';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return s;
    }
  }

  static Color _color(String s) {
    switch (s) {
      case 'pending_payment':
        return const Color(0xFFEAB308);
      case 'paid':
        return const Color(0xFF2563EB);
      case 'shipping':
        return const Color(0xFFF97316);
      case 'delivered':
        return const Color(0xFF16A34A);
      default:
        return AppColors.demoText;
    }
  }
}
