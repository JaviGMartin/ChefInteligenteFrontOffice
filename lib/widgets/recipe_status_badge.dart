import 'package:flutter/material.dart';

/// Badge que muestra el estado de validación de una receta:
/// Borrador, Pendiente (En Revisión), Publicada o Rechazada.
class RecipeStatusBadge extends StatelessWidget {
  const RecipeStatusBadge({
    super.key,
    required this.estado,
    this.compact = false,
  });

  /// Valor de recetas.estado: borrador | pendiente | publicada | aprobada | rechazada
  final String? estado;

  /// Si true, muestra solo el chip pequeño sin texto largo.
  final bool compact;

  static String label(String? estado) {
    final e = estado ?? '';
    if (e.isEmpty) return 'Sin estado';
    switch (e) {
      case 'borrador':
        return 'Borrador';
      case 'pendiente':
        return 'En Revisión';
      case 'publicada':
      case 'aprobada':
        return 'Publicada';
      case 'rechazada':
        return 'Rechazada';
      default:
        return e;
    }
  }

  static Color color(String? estado) {
    final e = estado ?? '';
    if (e.isEmpty) return Colors.grey;
    switch (e) {
      case 'borrador':
        return Colors.grey;
      case 'pendiente':
        return Colors.amber;
      case 'publicada':
      case 'aprobada':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData? icon(String? estado) {
    final e = estado ?? '';
    if (e.isEmpty) return null;
    switch (e) {
      case 'borrador':
        return Icons.edit_note;
      case 'pendiente':
        return Icons.schedule;
      case 'publicada':
      case 'aprobada':
        return Icons.check_circle_outline;
      case 'rechazada':
        return Icons.cancel_outlined;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelText = RecipeStatusBadge.label(estado);
    final badgeColor = RecipeStatusBadge.color(estado);
    final iconData = RecipeStatusBadge.icon(estado);

    if (compact) {
      return Tooltip(
        message: labelText,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconData != null) ...[
                Icon(iconData, size: 14, color: badgeColor),
                const SizedBox(width: 4),
              ],
              Text(
                labelText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: badgeColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 20, color: badgeColor),
              const SizedBox(width: 8),
            ],
            Text(
              labelText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
