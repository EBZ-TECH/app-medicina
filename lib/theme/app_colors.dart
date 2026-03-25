import 'package:flutter/material.dart';

/// Paleta MediConnect — tonos azules más oscuros (acciones, textos y fondos).
abstract final class AppColors {
  /// Azul principal (botones, bordes activos, enlaces, iconos de marca).
  static const Color primaryBlue = Color(0xFF0F3D73);

  /// Azul muy oscuro para títulos y texto principal.
  static const Color navy = Color(0xFF051A2E);

  static const Color borderGrey = Color(0xFFC5CED6);
  static const Color labelGrey = Color(0xFF4A5A6A);
  static const Color hintGrey = Color(0xFF7A8794);

  /// Fondo de pantalla (azul grisáceo suave).
  static const Color pageBackground = Color(0xFFE4EBF3);

  /// Tarjetas seleccionadas / cajas informativas (tinte del azul oscuro).
  static const Color demoBoxBackground = Color(0xFFC5D6E8);

  static const Color demoText = Color(0xFF3D4A56);
}
