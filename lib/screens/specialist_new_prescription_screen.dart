import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api_service.dart';
import '../services/prescriptions_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// Registro de fórmula hacia un paciente (correo registrado en MediConnect).
class SpecialistNewPrescriptionScreen extends StatefulWidget {
  const SpecialistNewPrescriptionScreen({super.key});

  @override
  State<SpecialistNewPrescriptionScreen> createState() => _SpecialistNewPrescriptionScreenState();
}

class _DrugLine {
  final TextEditingController name = TextEditingController();
  final TextEditingController dosage = TextEditingController();
  final TextEditingController posology = TextEditingController();
  final TextEditingController quantity = TextEditingController();

  void dispose() {
    name.dispose();
    dosage.dispose();
    posology.dispose();
    quantity.dispose();
  }
}

class _SpecialistNewPrescriptionScreenState extends State<SpecialistNewPrescriptionScreen> {
  final _api = PrescriptionsApiService();
  final _session = SessionService();
  final _emailCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'Fórmula médica');
  final _estimatedCtrl = TextEditingController();

  final List<_DrugLine> _lines = [_DrugLine()];
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _estimatedCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_DrugLine()));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _submit() async {
    final token = await _session.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión no válida')),
      );
      return;
    }
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el correo del paciente')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final n = l.name.text.trim();
      if (n.isEmpty) continue;
      final m = <String, dynamic>{'drug_name': n};
      if (l.dosage.text.trim().isNotEmpty) m['dosage'] = l.dosage.text.trim();
      if (l.posology.text.trim().isNotEmpty) m['posology'] = l.posology.text.trim();
      if (l.quantity.text.trim().isNotEmpty) {
        final q = int.tryParse(l.quantity.text.trim());
        if (q != null) m['quantity'] = q;
      }
      items.add(m);
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un medicamento con nombre')),
      );
      return;
    }

    int? est;
    if (_estimatedCtrl.text.trim().isNotEmpty) {
      est = int.tryParse(_estimatedCtrl.text.trim().replaceAll('.', ''));
    }

    setState(() => _busy = true);
    try {
      await _api.createSpecialist(
        accessToken: token,
        patientEmail: email,
        title: _titleCtrl.text.trim().isEmpty ? 'Fórmula médica' : _titleCtrl.text.trim(),
        items: items,
        estimatedTotalCents: est,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fórmula registrada')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          'Nueva fórmula',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Correo del paciente',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'paciente@correo.com',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Título (opcional)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Total estimado COP (opcional; si vacío se calcula por ítems)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _estimatedCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ej. 45000',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Medicamentos',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            for (var i = 0; i < _lines.length; i++) _DrugBlock(line: _lines[i], index: i, onRemove: () => _removeLine(i)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      'Registrar fórmula',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrugBlock extends StatelessWidget {
  final _DrugLine line;
  final int index;
  final VoidCallback onRemove;

  const _DrugBlock({
    required this.line,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Medicamento ${index + 1}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              const Spacer(),
              if (index > 0)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          TextField(
            controller: line.name,
            decoration: const InputDecoration(labelText: 'Nombre', border: UnderlineInputBorder()),
          ),
          TextField(
            controller: line.dosage,
            decoration: const InputDecoration(labelText: 'Dosis (opcional)', border: UnderlineInputBorder()),
          ),
          TextField(
            controller: line.posology,
            decoration: const InputDecoration(
              labelText: 'Indicación (opcional)',
              border: UnderlineInputBorder(),
            ),
          ),
          TextField(
            controller: line.quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad (opcional)',
              border: UnderlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
