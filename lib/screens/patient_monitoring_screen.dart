import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/monitoring_categories.dart';
import '../constants/specialties.dart';
import '../services/auth_api_service.dart';
import '../services/monitoring_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'request_consultation_screen.dart';

/// Panel 1.4: resultados, evolución, autorizaciones, recomendaciones y remisiones.
class PatientMonitoringScreen extends StatefulWidget {
  const PatientMonitoringScreen({super.key});

  @override
  State<PatientMonitoringScreen> createState() => _PatientMonitoringScreenState();
}

class _PatientMonitoringScreenState extends State<PatientMonitoringScreen> {
  final _api = MonitoringApiService();
  final _session = SessionService();

  String? _filterCategory;
  List<MonitoringEntryDto> _entries = [];
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
      final list = await _api.fetchEntries(
        accessToken: token,
        category: _filterCategory,
      );
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  Future<void> _applyFilter(String? cat) async {
    setState(() => _filterCategory = cat);
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _api.fetchEntries(accessToken: token, category: cat);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _openConsultationFromReferral(MonitoringEntryDto e) {
    final spec = e.referralTargetSpecialty?.trim();
    final validSpec = spec != null && spec.isNotEmpty && kMedicalSpecialties.contains(spec) ? spec : null;
    final desc = StringBuffer('Seguimiento por remisión indicada en MediConnect: ${e.title}.');
    if (e.summary != null && e.summary!.trim().isNotEmpty) {
      desc.write(' ${e.summary!.trim()}');
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestConsultationScreen(
          initialSpecialty: validSpec,
          initialDescription: desc.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Seguimiento',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _filterCategory == null,
                    onSelected: (_) => _applyFilter(null),
                  ),
                  const SizedBox(width: 6),
                  ...kMonitoringCategoryLabels.entries.map(
                    (kv) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(kv.value),
                        selected: _filterCategory == kv.key,
                        onSelected: (_) => _applyFilter(kv.key),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF2563EB),
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: GoogleFonts.inter(color: Colors.red.shade800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    }
    if (_entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: AppColors.hintGrey),
          const SizedBox(height: 12),
          Text(
            'Aún no hay registros en tu seguimiento.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando tu equipo médico documente resultados, autorizaciones, recomendaciones o remisiones, aparecerán aquí.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.demoText, height: 1.4),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = _entries[i];
        return _MonitoringCard(
          entry: e,
          onReferralConsult: e.category == 'referral' ? () => _openConsultationFromReferral(e) : null,
        );
      },
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  final MonitoringEntryDto entry;
  final VoidCallback? onReferralConsult;

  const _MonitoringCard({
    required this.entry,
    this.onReferralConsult,
  });

  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final catLabel = kMonitoringCategoryLabels[entry.category] ?? entry.category;
    final dateStr = entry.occurredAt ?? entry.createdAt ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(monitoringCategoryIcon(entry.category), color: _blue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
            ),
          ],
          if (entry.specialistDisplayName != null && entry.specialistDisplayName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Profesional: ${entry.specialistDisplayName}'
              '${entry.specialistSpecialty != null && entry.specialistSpecialty!.isNotEmpty ? ' · ${entry.specialistSpecialty}' : ''}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
            ),
          ],
          if (entry.summary != null && entry.summary!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.summary!.trim(),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText, height: 1.35),
            ),
          ],
          if (entry.detail != null && entry.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.detail!.trim(),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy, height: 1.35),
            ),
          ],
          if (entry.category == 'referral') ...[
            const SizedBox(height: 8),
            if (entry.referralTargetSpecialty != null && entry.referralTargetSpecialty!.isNotEmpty)
              Text(
                'Especialidad indicada: ${entry.referralTargetSpecialty}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
            if (entry.referralSpecialistDisplayName != null &&
                entry.referralSpecialistDisplayName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Especialista sugerido: ${entry.referralSpecialistDisplayName}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
              ),
            ],
            if (onReferralConsult != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onReferralConsult,
                  child: Text(
                    'Solicitar consulta por esta remisión',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
