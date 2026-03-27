import 'package:flutter/material.dart';

/// Categorías alineadas con `patient_care_entries.category` en el backend.
const Map<String, String> kMonitoringCategoryLabels = {
  'therapy_result': 'Resultados terapia',
  'evolution': 'Evolución',
  'authorization': 'Autorizaciones',
  'recommendation': 'Recomendaciones',
  'referral': 'Remisiones',
};

IconData monitoringCategoryIcon(String category) {
  switch (category) {
    case 'therapy_result':
      return Icons.healing_outlined;
    case 'evolution':
      return Icons.trending_up_rounded;
    case 'authorization':
      return Icons.verified_user_outlined;
    case 'recommendation':
      return Icons.medical_information_outlined;
    case 'referral':
      return Icons.swap_horiz_rounded;
    default:
      return Icons.folder_outlined;
  }
}
