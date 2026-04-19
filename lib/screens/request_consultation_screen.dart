import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/specialties.dart';
import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'request_consultation_form_data.dart';
import 'request_consultation_step1_fields.dart';

/// Flujo: información → detalles por especialidad → elección de especialista.
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
  final _authApi = AuthApiService();
  final RequestConsultationFormData _form = RequestConsultationFormData();

  Map<String, dynamic> _patientProfile = {};
  bool _loadingProfile = true;

  int _step = 0;
  /// Antes de elegir especialista: 0 datos + agenda + antecedentes + tipo; 1 detalles por especialidad.
  int _formSection = 0;

  /// Índice 0–2 para la barra superior única (3 segmentos).
  int get _flowStepIndex {
    if (_step >= 1) return 2;
    if (_formSection >= 1) return 1;
    return 0;
  }
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
      _form.antecedentes.text = d;
    }
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final p = await _authApi.me(token);
      if (!mounted) return;
      setState(() {
        _patientProfile = p;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
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

  void _goFormDetailsStep() {
    final err = _form.validateScheduling() ?? _form.validateSpecialtySelected(_specialty);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _formSection = 1);
  }

  void _goStep2() {
    final err = _form.validateStep1(_specialty);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() {
      _step = 1;
      _formSection = 1;
      _selectedSpecialistId = null;
    });
    if (_chooseSpecialistManually) {
      _loadSpecialists();
    } else {
      _checkAutoAvailability();
    }
  }

  /// Borrador al abrir el selector: cita guardada o mañana a las 10:00.
  DateTime _draftScheduleStart(DateTime now) {
    if (_form.scheduledAt != null) return _form.scheduledAt!;
    final next = now.add(const Duration(days: 1));
    return DateTime(next.year, next.month, next.day, 10, 0);
  }

  static const _weekdayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  String _scheduleDateOnlyLabel(DateTime d) {
    final w = _weekdayNames[d.weekday - 1];
    final m = _monthNames[d.month - 1];
    return '$w ${d.day} de $m de ${d.year}';
  }

  /// Texto legible en español (2 líneas: fecha · hora).
  String _scheduleHumanSummary(DateTime d) {
    return '${_scheduleDateOnlyLabel(d)}\n${_fmtTime(d)}';
  }

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    final firstCalendarDate = DateTime(now.year, now.month, now.day);
    final lastCalendarDate = now.add(const Duration(days: 365));

    final draft = _draftScheduleStart(now);
    var initialCal = DateTime(draft.year, draft.month, draft.day);
    if (initialCal.isBefore(firstCalendarDate)) initialCal = firstCalendarDate;
    if (initialCal.isAfter(lastCalendarDate)) initialCal = lastCalendarDate;

    if (!mounted) return;
    final pickedDay = await showDatePicker(
      context: context,
      initialDate: initialCal,
      firstDate: firstCalendarDate,
      lastDate: lastCalendarDate,
      helpText: 'Paso 1 de 2 · Elige el día',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
    );
    if (pickedDay == null || !mounted) return;

    TimeOfDay initialTime;
    final prev = _form.scheduledAt;
    if (prev != null &&
        prev.year == pickedDay.year &&
        prev.month == pickedDay.month &&
        prev.day == pickedDay.day) {
      initialTime = TimeOfDay.fromDateTime(prev);
    } else {
      initialTime = const TimeOfDay(hour: 10, minute: 0);
    }

    if (!mounted) return;
    final dateLabel = _scheduleDateOnlyLabel(pickedDay);
    final timeResult = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        var hour = initialTime.hour;
        var minute = initialTime.minute;
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Paso 2 de 2 · Elige la hora',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  dateLabel,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Desliza las ruedas para elegir hora y minutos (formato 24 h).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.demoText,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(2000, 1, 1, hour, minute),
                    onDateTimeChanged: (dt) {
                      hour = dt.hour;
                      minute = dt.minute;
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.demoText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final combined = DateTime(
                            pickedDay.year,
                            pickedDay.month,
                            pickedDay.day,
                            hour,
                            minute,
                          );
                          if (!combined.isAfter(now)) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  pickedDay.year == now.year &&
                                          pickedDay.month == now.month &&
                                          pickedDay.day == now.day
                                      ? 'Para hoy, elige una hora que sea posterior a la hora actual.'
                                      : 'La fecha y hora deben ser posteriores a ahora.',
                                  style: GoogleFonts.inter(),
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(sheetContext).pop(
                            TimeOfDay(hour: hour, minute: minute),
                          );
                        },
                        child: Text(
                          'Guardar hora',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (timeResult == null || !mounted) return;
    setState(() {
      _form.scheduledAt = DateTime(
        pickedDay.year,
        pickedDay.month,
        pickedDay.day,
        timeResult.hour,
        timeResult.minute,
      );
    });
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
      final details = _form.buildDetailsJson(_specialty!.trim());
      final result = await _api.createRequest(
        accessToken: token,
        specialty: _specialty!.trim(),
        scheduledAt: _form.scheduledAt!,
        modality: _form.modality!,
        priority: _form.priority!,
        antecedentes: _form.antecedentes.text.trim().isEmpty ? null : _form.antecedentes.text.trim(),
        details: details,
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
            _ThreeStepProgressBar(activeIndex: _flowStepIndex),
            const SizedBox(height: 20),
            if (_step == 0) _buildStep1Card() else _buildStep2Card(),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco() {
    return InputDecoration(
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
          if (_formSection == 0) _buildFormSection0(),
          if (_formSection == 1) _buildFormSectionDetails(),
        ],
      ),
    );
  }

  Widget _buildFormSection0() {
    final fn = (_patientProfile['first_name'] as String?)?.trim() ?? '';
    final ln = (_patientProfile['last_name'] as String?)?.trim() ?? '';
    final name = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    final email = (_patientProfile['email'] as String?)?.trim();
    final phone = (_patientProfile['phone'] as String?)?.trim();
    final age = _patientProfile['age'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paso 1 de 3 · Datos, agenda y tipo de consulta',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu información',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingProfile)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Paciente' : name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email, style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText)),
                ],
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Celular: $phone', style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText)),
                ],
                if (age != null) ...[
                  const SizedBox(height: 4),
                  Text('Edad: $age años', style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText)),
                ],
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Fecha y hora preferida',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickSchedule,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_calendar_outlined,
                    color: _primaryBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _form.scheduledAt == null
                        ? Text(
                            'Toca para elegir: primero el día, luego la hora',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          )
                        : Text(
                            _scheduleHumanSummary(_form.scheduledAt!).replaceAll('\n', ' · '),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Modalidad',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _form.modality,
          isExpanded: true,
          decoration: _fieldDeco(),
          hint: Text('Selecciona', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
          items: RequestConsultationFormData.modalidades
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(RequestConsultationFormData.labelModalidad(m)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _form.modality = v),
        ),
        const SizedBox(height: 16),
        Text(
          'Prioridad',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _form.priority,
          isExpanded: true,
          decoration: _fieldDeco(),
          hint: Text('Selecciona', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
          items: RequestConsultationFormData.prioridades
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(RequestConsultationFormData.labelPrioridad(p)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _form.priority = v),
        ),
        const SizedBox(height: 16),
        Text(
          'Antecedentes relevantes',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _form.antecedentes,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: _fieldDeco().copyWith(
            hintText: 'Alergias, cirugías previas, medicación, etc. (opcional)',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
          ),
        ),
        const SizedBox(height: 16),
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
          value: _specialty,
          isExpanded: true,
          decoration: _fieldDeco(),
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
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _goFormDetailsStep,
            child: Text(
              'Siguiente',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSectionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paso 2 de 3 · Detalles de la consulta',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _primaryBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _specialty == null ? 'Selecciona tipo de consulta en el paso anterior' : _specialty!,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 16),
        if (_specialty != null)
          RequestConsultationStep1Fields(
            specialty: _specialty,
            fd: _form,
            onChanged: () => setState(() {}),
          )
        else
          Text(
            'Vuelve atrás y elige un tipo de consulta.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.demoText),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _formSection = 0),
                  child: Text(
                    'Atrás',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _specialty == null ? null : _goStep2,
                  child: Text(
                    'Siguiente',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
                'Paso 3 de 3 · Especialista',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
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
                            _formSection = 1;
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

/// Una sola barra de progreso con 3 segmentos (sin indicador anidado en la tarjeta).
class _ThreeStepProgressBar extends StatelessWidget {
  /// Paso actual: 0 = información, 1 = detalles, 2 = especialista.
  final int activeIndex;

  const _ThreeStepProgressBar({required this.activeIndex});

  static const _blue = Color(0xFF2563EB);
  static const _grey = Color(0xFFE5E7EB);
  static const _labels = ['Información', 'Detalles', 'Especialista'];

  @override
  Widget build(BuildContext context) {
    final idx = activeIndex.clamp(0, 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i <= idx;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: filled ? _blue : _grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Text(
                _labels[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : i == 2
                        ? TextAlign.right
                        : TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            );
          }),
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
