import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Muestra una valoración de 1 a 5 con estrellas (verde lima cuando rellenas).
/// [rating] puede ser 0–5 (double); se redondea para pintar estrellas.
/// Si [onTap] no es null, las estrellas son pulsables (p. ej. para ir a comentarios).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.onTap,
  });

  final double? rating;
  final double size;
  final VoidCallback? onTap;

  /// Número entero de estrellas a mostrar rellenas (1–5). Si null o 0, se muestran vacías.
  static int filledCount(double? r) {
    if (r == null || r <= 0) return 0;
    if (r >= 5) return 5;
    return r.round().clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    final filled = StarRating.filledCount(rating);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final green = AppColors.brandGreen;

    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = (i + 1) <= filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            size: size,
            color: isFilled ? green : color,
          ),
        );
      }),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      );
    }
    return row;
  }
}
