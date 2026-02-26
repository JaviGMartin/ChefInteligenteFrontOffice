import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';

/// Logo oficial ChefPlanner.es (igual que en splash).
/// Círculo blanco con gorro de chef azul y check verde, texto Chef / Planner / .es y opcional tagline.
class ChefPlannerLogo extends StatelessWidget {
  const ChefPlannerLogo({
    super.key,
    this.size = 1.0,
    this.showTagline = true,
  });

  /// Escala del logo (1.0 = tamaño splash; 0.7 = más pequeño para login).
  final double size;

  /// Si se muestra "Gestión Inteligente de Cocina".
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(32 * s),
          decoration: BoxDecoration(
            color: AppColors.brandWhite,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24 * s,
                spreadRadius: 2 * s,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                LucideIcons.chefHat,
                size: 80 * s,
                color: AppColors.brandBlue,
              ),
              Positioned(
                top: -8 * s,
                right: -8 * s,
                child: Container(
                  padding: EdgeInsets.all(8 * s),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandBlue, width: 4),
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 28 * s,
                    color: AppColors.brandWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8 * s),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: AppColors.brandWhite,
              fontSize: 36 * s,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: [
              const TextSpan(text: 'Chef'),
              TextSpan(
                text: 'Planner',
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  color: AppColors.brandWhite.withValues(alpha: 0.95),
                ),
              ),
              TextSpan(
                text: '.es',
                style: TextStyle(
                  color: AppColors.brandGreen,
                  fontSize: 36 * s,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: 8 * s),
          Text(
            'Gestión Inteligente de Cocina',
            style: TextStyle(
              color: AppColors.brandWhite.withValues(alpha: 0.8),
              fontSize: 12 * s,
              letterSpacing: 4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
