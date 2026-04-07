import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/payment_plans.dart';
import '../theme/app_colors.dart';

/// Pestaña Perfil: datos del paciente y acceso al plan de pago.
class PatientProfileScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool planBusy;
  final bool profileBusy;
  final String? profilePhotoUrl;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenPaymentPlan;

  const PatientProfileScreen({
    super.key,
    required this.profile,
    required this.planBusy,
    required this.profileBusy,
    required this.profilePhotoUrl,
    required this.onEditProfile,
    required this.onOpenPaymentPlan,
  });

  String get _paymentPlanCode =>
      (profile['payment_plan'] as String?) ?? kPaymentPlanPayPerConsult;

  @override
  Widget build(BuildContext context) {
    final first = (profile['first_name'] as String?)?.trim() ?? '';
    final last = (profile['last_name'] as String?)?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    final email = (profile['email'] as String?) ?? '—';
    final phone = (profile['phone'] as String?) ?? '—';
    final age = profile['age'];
    final ageStr = age == null ? '—' : '$age años';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFEFF6FF),
                      backgroundImage:
                          (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
                              ? NetworkImage(profilePhotoUrl!)
                              : null,
                      child: (profilePhotoUrl == null || profilePhotoUrl!.isEmpty)
                          ? Text(
                              _initials(first, last),
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2563EB),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Paciente' : name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoSection(
            children: [
              _InfoRow(icon: Icons.phone_outlined, label: 'Celular', value: phone),
              _InfoRow(icon: Icons.cake_outlined, label: 'Edad', value: ageStr),
              _InfoRow(
                icon: Icons.payment_outlined,
                label: 'Plan',
                value: paymentPlanLabel(_paymentPlanCode),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: profileBusy ? null : onEditProfile,
              icon: profileBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
              label: Text(
                profileBusy ? 'Guardando...' : 'Editar foto y celular',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                foregroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: planBusy ? null : onOpenPaymentPlan,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: planBusy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      'Cambiar modalidad de pago',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String first, String last) {
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final s = ('$a$b').toUpperCase();
    if (s.isEmpty) return '?';
    return s.length > 2 ? s.substring(0, 2) : s;
  }
}

class _InfoSection extends StatelessWidget {
  final List<Widget> children;

  const _InfoSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.labelGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
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
