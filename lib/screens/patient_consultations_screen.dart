import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// 1.7 — Lista de consultas y calificación del especialista (1–5).
class PatientConsultationsScreen extends StatefulWidget {
  const PatientConsultationsScreen({super.key});

  @override
  State<PatientConsultationsScreen> createState() => _PatientConsultationsScreenState();
}

class _PatientConsultationsScreenState extends State<PatientConsultationsScreen> {
  final _api = ConsultationApiService();
  final _session = SessionService();

  List<ConsultationSummaryDto> _items = [];
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
      final list = await _api.fetchPatientConsultations(accessToken: token);
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

  Future<void> _openRateSheet(ConsultationSummaryDto c) async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;

    int stars = 5;
    final commentCtrl = TextEditingController();

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: StatefulBuilder(
              builder: (context, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Calificar atención',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.specialistLabel ?? c.specialty,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.demoText),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final n = i + 1;
                        return IconButton(
                          onPressed: () => setModal(() => stars = n),
                          icon: Icon(
                            n <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: n <= stars ? const Color(0xFFEAB308) : AppColors.demoText,
                            size: 36,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'Comentario (opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Enviar calificación', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );

      if (ok != true || !mounted) return;

      try {
        await _api.rateConsultation(
          accessToken: token,
          consultationId: c.id,
          rating: stars,
          comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por tu calificación')),
        );
        await _load();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar')),
        );
      }
    } finally {
      commentCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Mis consultas', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade800)),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aún no tienes solicitudes de consulta.',
                              style: GoogleFonts.inter(color: AppColors.demoText),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          final rated = c.myRating != null;
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
                                    c.specialistLabel ?? c.specialty,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.specialty,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
                                  ),
                                  if (c.scheduledAt != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Cita: ${c.scheduledAt}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryBlue),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  if (rated)
                                    Row(
                                      children: [
                                        Text(
                                          'Tu calificación: ',
                                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
                                        ),
                                        ...List.generate(
                                          5,
                                          (j) => Icon(
                                            j < (c.myRating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                                            size: 18,
                                            color: const Color(0xFFEAB308),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (c.canRate)
                                    FilledButton.icon(
                                      onPressed: () => _openRateSheet(c),
                                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                                      label: const Text('Calificar especialista'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                      ),
                                    )
                                  else
                                    Text(
                                      'Podrás calificar cuando la cita haya pasado o tras el pago simulado.',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
