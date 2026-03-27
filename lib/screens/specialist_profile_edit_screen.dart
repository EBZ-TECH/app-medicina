import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// 1.8 — Bio, años de experiencia y foto de perfil (público en listado de especialistas).
class SpecialistProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const SpecialistProfileEditScreen({super.key, required this.profile});

  @override
  State<SpecialistProfileEditScreen> createState() => _SpecialistProfileEditScreenState();
}

class _SpecialistProfileEditScreenState extends State<SpecialistProfileEditScreen> {
  final _auth = AuthApiService();
  final _session = SessionService();
  late final TextEditingController _bioCtrl;
  late final TextEditingController _yearsCtrl;
  bool _saving = false;
  PlatformFile? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: (widget.profile['bio_short'] as String?) ?? '');
    final y = widget.profile['years_experience'];
    _yearsCtrl = TextEditingController(
      text: y != null ? '$y' : '',
    );
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;

    int? years;
    final ys = _yearsCtrl.text.trim();
    if (ys.isNotEmpty) {
      years = int.tryParse(ys);
      if (years == null || years < 0 || years > 80) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Años de experiencia: 0–80')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await _auth.patchSpecialistProfile(
        accessToken: token,
        bioShort: _bioCtrl.text.trim(),
        yearsExperience: years,
        clearYearsExperience: ys.isEmpty,
      );
      if (_pickedPhoto != null) {
        await _auth.patchSpecialistPublic(
          accessToken: token,
          profilePhoto: _pickedPhoto,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() => _pickedPhoto = r.files.first);
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = widget.profile['profile_photo_path'] as String?;
    final photoUrl = specialistProfilePhotoUrl(photoPath);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Mi perfil público', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: _pickedPhoto?.bytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _pickedPhoto!.bytes!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        )
                      : photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                photoUrl,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.person, size: 48, color: AppColors.demoText),
                              ),
                            )
                          : const Icon(Icons.person, size: 48, color: AppColors.demoText),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton.filled(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La calificación media (${widget.profile['average_rating'] ?? '—'}) se actualiza con las calificaciones de los pacientes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bioCtrl,
            maxLines: 5,
            maxLength: 600,
            decoration: InputDecoration(
              labelText: 'Descripción breve (bio)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _yearsCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Años de experiencia',
              hintText: 'Opcional',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Guardar', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
