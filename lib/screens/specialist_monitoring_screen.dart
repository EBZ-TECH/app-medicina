import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/monitoring_categories.dart';
import '../services/auth_api_service.dart';
import '../services/monitoring_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// 1.9 — Resultados, remisiones y seguimiento registrados por el especialista.
class SpecialistMonitoringScreen extends StatefulWidget {
  const SpecialistMonitoringScreen({super.key});

  @override
  State<SpecialistMonitoringScreen> createState() => _SpecialistMonitoringScreenState();
}

class _SpecialistMonitoringScreenState extends State<SpecialistMonitoringScreen> {
  final _api = MonitoringApiService();
  final _session = SessionService();

  List<MonitoringEntryDto> _items = [];
  bool _loading = true;
  String? _error;
  String? _filterCategory;

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
      final list = await _api.fetchSpecialistEntries(
        accessToken: token,
        category: _filterCategory,
      );
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Seguimiento clínico', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _filterCategory == null,
                  onSelected: (_) {
                    setState(() => _filterCategory = null);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(kMonitoringCategoryLabels['referral'] ?? 'Remisión'),
                  selected: _filterCategory == 'referral',
                  onSelected: (_) {
                    setState(() => _filterCategory = 'referral');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(kMonitoringCategoryLabels['therapy_result'] ?? 'Resultados'),
                  selected: _filterCategory == 'therapy_result',
                  onSelected: (_) {
                    setState(() => _filterCategory = 'therapy_result');
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade800)),
                          ],
                        )
                      : _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No hay entradas aún.',
                                    style: GoogleFonts.inter(color: AppColors.demoText),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final e = _items[i];
                                final cat = kMonitoringCategoryLabels[e.category] ?? e.category;
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          e.title,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                        if (e.patientDisplayName != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Paciente: ${e.patientDisplayName}',
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
                                          ),
                                        ],
                                        if (e.summary != null && e.summary!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            e.summary!,
                                            style: GoogleFonts.inter(fontSize: 13, height: 1.35),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
