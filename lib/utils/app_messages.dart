import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Feedback uniforme para acciones aún no conectadas al backend.
Future<void> showFeatureMessage(
  BuildContext context, {
  required String title,
  String? body,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: Text(
        body ??
            'Esta función se conectará al backend en una siguiente versión. '
            'Por ahora puedes usar registro, inicio de sesión y cerrar sesión.',
        style: GoogleFonts.inter(
          fontSize: 14,
          height: 1.4,
          color: AppColors.demoText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            'Entendido',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    ),
  );
}
