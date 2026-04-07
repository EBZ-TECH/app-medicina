import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/specialties.dart';
import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// Flujo en dos pasos: información → elección de especialista (manual o automático).
class RequestConsultationScreen extends StatefulWidget {
  /// Si viene de una remisión, puede rellenar especialidad y texto base.
  final String? initialSpecialty;
  final String? initialDescription;

  const RequestConsultationScreen({
    super.key,
    this.initialSpecialty,
    this.initialDescription,
  });

  @override
  State<RequestConsultationScreen> createState() => _RequestConsultationScreenState();
}

class _RequestConsultationScreenState extends State<RequestConsultationScreen> {
  static const _primaryBlue = Color(0xFF2563EB);

  final _session = SessionService();
  final _api = ConsultationApiService();
  final _descriptionController = TextEditingController();

  int _step = 0;
  String? _specialty;
  bool _chooseSpecialistManually = true;
  String? _selectedSpecialistId;

  List<SpecialistDto> _specialists = [];
  bool _loadingSpecialists = false;
  String? _specialistsError;
  bool _submitting = false;

  /// Asignación automática solo si hay al menos un especialista para esa especialidad.
  bool _autoAssignAvailable = true;
  bool _checkingAuto = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSpecialty?.trim();
    if (s != null && s.isNotEmpty && kMedicalSpecialties.contains(s)) {
      _specialty = s;
    }
    final d = widget.initialDescription?.trim();
    if (d != null && d.isNotEmpty) {
      _descriptionController.text = d;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _step1Valid {
    final desc = _descriptionController.text.trim();
    return _specialty != null &&
        _specialty!.isNotEmpty &&
        desc.length >= 5;
  }

  bool get _canConfirm {
    if (_chooseSpecialistManually) {
      return _selectedSpecialistId != null && _selectedSpecialistId!.isNotEmpty;
    }
    return _autoAssignAvailable && !_checkingAuto;
  }

  Future<void> _loadSpecialists() async {
    final token = await _session.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _specialistsError = 'Sesión no válida. Vuelve a iniciar sesión.';
      });
      return;
    }
    final spec = (_specialty ?? '').trim();
    setState(() {
      _loadingSpecialists = true;
      _specialistsError = null;
      _specialists = [];
      _selectedSpecialistId = null;
    });
    try {
      final list = await _api.fetchSpecialists(accessToken: token, specialty: spec);
      if (!mounted) return;
      setState(() {
        _specialists = list;
        _loadingSpecialists = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _specialistsError = e.message;
        _loadingSpecialists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _specialistsError = e.toString();
        _loadingSpecialists = false;
      });
    }
  }

  Future<void> _checkAutoAvailability() async {
    final token = await _session.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _autoAssignAvailable = false;
        _checkingAuto = false;
      });
      return;
    }
    final spec = (_specialty ?? '').trim();
    if (spec.isEmpty) return;
    setState(() {
      _checkingAuto = true;
      _autoAssignAvailable = true;
    });
    try {
      final list = await _api.fetchSpecialists(accessToken: token, specialty: spec);
      if (!mounted) return;
      setState(() {
        _autoAssignAvailable = list.isNotEmpty;
        _checkingAuto = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _autoAssignAvailable = false;
        _checkingAuto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoAssignAvailable = false;
        _checkingAuto = false;
      });
    }
  }

  void _goStep2() {
    if (!_step1Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona especialidad y describe tu necesidad (mín. 5 caracteres).')),
      );
      return;
    }
    setState(() {
      _step = 1;
      _selectedSpecialistId = null;
    });
    if (_chooseSpecialistManually) {
      _loadSpecialists();
    } else {
      _checkAutoAvailability();
    }
  }

  Future<void> _submit() async {
    if (!_canConfirm || _submitting) return;
    final token = await _session.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión no válida.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _api.createRequest(
        accessToken: token,
        specialty: _specialty!.trim(),
        description: _descriptionController.text.trim(),
        automaticAssignment: !_chooseSpecialistManually,
        specialistId: _chooseSpecialistManually ? _selectedSpecialistId : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
            const Icon(Icons.favorite, color: _primaryBlue, size: 22),
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
            onPressed: () => Navigator.of(context).maybePop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.demoText),
                const SizedBox(width: 4),
                Text(
                  'Volver',
                  style: GoogleFonts.inter(
                    color: AppColors.demoText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solicitar consulta',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            _StepperRow(step: _step),
            const SizedBox(height: 20),
            if (_step == 0) _buildStep1Card() else _buildStep2Card(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Card() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tipo de consulta',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: _specialty,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
              ),
            ),
            hint: Text(
              'Selecciona una especialidad',
              style: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Selecciona una especialidad'),
              ),
              ...kMedicalSpecialties.map(
                (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
              ),
            ],
            onChanged: (v) => setState(() => _specialty = v),
          ),
          const SizedBox(height: 18),
          Text(
            'Descripción de tu necesidad',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Describe los síntomas o motivo de consulta...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _goStep2,
              child: Text(
                'Continuar',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Card() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Cómo deseas elegir tu especialista?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              _AssignmentOptionCard(
                selected: _chooseSpecialistManually,
                title: 'Elegir especialista',
                subtitle: 'Selecciona el especialista que prefieras',
                icon: null,
                onTap: () {
                  setState(() {
                    _chooseSpecialistManually = true;
                    _selectedSpecialistId = null;
                  });
                  _loadSpecialists();
                },
              ),
              const SizedBox(height: 10),
              _AssignmentOptionCard(
                selected: !_chooseSpecialistManually,
                title: 'Asignación automática',
                subtitle: 'Asignación aleatoria entre especialistas de esta especialidad (~1 min)',
                icon: Icons.shuffle_rounded,
                onTap: () {
                  setState(() {
                    _chooseSpecialistManually = false;
                    _selectedSpecialistId = null;
                    _specialists = [];
                    _specialistsError = null;
                  });
                  _checkAutoAvailability();
                },
              ),
              if (!_chooseSpecialistManually && _checkingAuto) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Comprobando disponibilidad…',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_chooseSpecialistManually && !_checkingAuto && !_autoAssignAvailable) ...[
                const SizedBox(height: 12),
                Text(
                  'No hay especialistas para esta especialidad: no se puede usar asignación automática. '
                  'Elige manualmente o cambia el tipo de consulta en el paso anterior.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade800, height: 1.35),
                ),
              ],
              if (_chooseSpecialistManually) ...[
                const SizedBox(height: 22),
                Text(
                  'Especialistas disponibles',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingSpecialists)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
                  )
                else if (_specialistsError != null)
                  Text(
                    _specialistsError!,
                    style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13),
                  )
                else if (_specialists.isEmpty)
                  Text(
                    'No hay especialistas registrados con esta especialidad. '
                    'Debe existir al menos un profesional dado de alta con el mismo tipo de consulta.',
                    style: GoogleFonts.inter(color: AppColors.demoText, fontSize: 13, height: 1.4),
                  )
                else
                  ..._specialists.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SpecialistTile(
                          specialist: s,
                          selected: _selectedSpecialistId == s.id,
                          onTap: () => setState(() => _selectedSpecialistId = s.id),
                        ),
                      )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() {
                            _step = 0;
                          });
                        },
                  child: Text(
                    'Volver',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_submitting || !_canConfirm) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Confirmar consulta',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  final int step;

  const _StepperRow({required this.step});

  static const _blue = Color(0xFF2563EB);
  static const _grey = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final secondActive = step >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: secondActive ? _blue : _grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Información',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Seleccionar especialista',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssignmentOptionCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  const _AssignmentOptionCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _blue : const Color(0xFFD1D5DB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _blue, size: 26),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.demoText,
                        height: 1.3,
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

class _SpecialistTile extends StatelessWidget {
  final SpecialistDto specialist;
  final bool selected;
  final VoidCallback onTap;

  const _SpecialistTile({
    required this.specialist,
    required this.selected,
    required this.onTap,
  });

  static const _blue = Color(0xFF2563EB);

  String _initials() {
    final a = specialist.firstName.isNotEmpty ? specialist.firstName[0] : '';
    final b = specialist.lastName.isNotEmpty ? specialist.lastName[0] : '';
    return ('$a$b').toUpperCase();
  }

  Widget _avatar() {
    final url = specialist.photoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: 26,
      backgroundColor: _blue,
      child: Text(
        _initials(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _blue : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${specialist.displayName} — ${specialist.specialty}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StarRow(rating: specialist.rating, hasRating: specialist.hasRating),
                    if (!specialist.availableForAssignments) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fuera de servicio (sigue pudiendo atenderte)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (specialist.yearsExperience != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Experiencia: ${specialist.yearsExperience} años',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.demoText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      specialist.bio,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.demoText,
                        height: 1.35,
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

class _StarRow extends StatelessWidget {
  final double? rating;
  final bool hasRating;

  const _StarRow({required this.rating, required this.hasRating});

  @override
  Widget build(BuildContext context) {
    if (!hasRating || rating == null) {
      return Text(
        'Sin calificaciones aún',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.hintGrey,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final r = rating!.clamp(0, 5);
    final full = r.floor().clamp(0, 5);
    final hasHalf = (r - full) >= 0.5 && full < 5;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < full) {
            return const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308));
          }
          if (i == full && hasHalf) {
            return const Icon(Icons.star_half_rounded, size: 18, color: Color(0xFFEAB308));
          }
          return Icon(Icons.star_outline_rounded, size: 18, color: Colors.grey.shade400);
        }),
        const SizedBox(width: 6),
        Text(
          r.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.demoText,
          ),
        ),
      ],
    );
  }
}
