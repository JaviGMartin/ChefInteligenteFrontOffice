import 'package:flutter/material.dart';

/// Colores de marca ChefPlanner.es
/// Guía: Azul (#1B263B), Verde lima (#70E000), Blanco (#FFFFFF)
/// Fondo: gris acero inoxidable (cocina profesional)
class AppColors {
  AppColors._();

  static const Color brandBlue = Color(0xFF1B263B);
  /// Verde lima: acento para éxito, checkmarks, detalles
  static const Color brandGreen = Color(0xFF70E000);
  static const Color brandWhite = Color(0xFFFFFFFF);

  /// Gris acero inoxidable (fondo principal de la app)
  static const Color stainlessLight = Color(0xFFE2E3E5);
  static const Color stainless = Color(0xFFC5C6C8);
  static const Color stainlessDark = Color(0xFFA8AAAD);

  /// Degradado efecto acero inoxidable para fondos
  static const LinearGradient stainlessGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [stainlessLight, stainless, stainlessDark],
    stops: [0.0, 0.5, 1.0],
  );

  /// Texto/iconos sobre fondo acero: buen contraste
  static const Color onStainless = Color(0xFF2C2C2E);
  static const Color onStainlessMuted = Color(0xFF6B7280);
}

/// Envuelve el contenido con fondo degradado acero inoxidable.
/// Usa DecoratedBox para no alterar las restricciones del hijo (evita pantalla en blanco).
class StainlessBackground extends StatelessWidget {
  const StainlessBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.stainlessGradient),
      child: child,
    );
  }
}
