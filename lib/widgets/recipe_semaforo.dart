import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';

/// Lógica reutilizable del semáforo de recetas (stock/disponibilidad).
/// Usado en RecipeListScreen, KitchenFunnelScreen y RecipeDetailScreen.
class RecipeSemaforo {
  RecipeSemaforo._();

  static String texto(Recipe recipe) {
    final estadoCompleto = recipe.estadoDisponibilidadCompleta;
    if (estadoCompleto == 'en_camino') {
      return 'Ingredientes en lista de compra';
    }
    final salud = recipe.estadoSalud;
    final porcentaje = recipe.porcentajeStock;
    final cocinable = recipe.esCocinable ?? false;
    final stockOK = porcentaje == 100 || cocinable;
    // Stock suficiente: listo para cocinar (con o sin avisos de intolerancias)
    if (stockOK) {
      if (salud == 'success') return '¡Listo para cocinar!';
      return 'Listo para cocinar (con avisos)';
    }
    if (porcentaje != null && porcentaje > 0 && porcentaje < 100) {
      return 'Faltan algunos ingredientes';
    }
    if (salud == 'warning' && !stockOK) {
      return 'Faltan algunos ingredientes';
    }
    if (porcentaje == 0 || (porcentaje == null && !cocinable)) {
      return 'Sin existencias';
    }
    if (salud == 'danger' && !stockOK) {
      return 'Sin existencias';
    }
    if (salud == 'gray') {
      return 'Sin datos de ingredientes';
    }
    return 'Faltan algunos ingredientes';
  }

  static Color color(Recipe recipe) {
    if (recipe.estadoDisponibilidadCompleta == 'en_camino') {
      return Colors.blue;
    }
    final texto = RecipeSemaforo.texto(recipe);
    if (texto == '¡Listo para cocinar!' || texto == 'Listo para cocinar (con avisos)') return Colors.green;
    if (texto == 'Faltan algunos ingredientes') return Colors.orange;
    return Colors.red;
  }

  /// Color solo para el indicador de stock (%). Verde si 100%, naranja si parcial, rojo si 0.
  static Color colorSoloStock(Recipe recipe) {
    final p = recipe.porcentajeStock;
    if (p == null) return Colors.grey;
    if (p >= 100) return Colors.green;
    if (p > 0) return Colors.orange;
    return Colors.red;
  }

  static Color colorFromEstado(String? estadoSalud) {
    switch (estadoSalud) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.amber;
      case 'danger':
        return Colors.red;
      case 'gray':
      default:
        return Colors.grey;
    }
  }

  static bool isDanger(Recipe recipe) {
    return recipe.estadoSalud == 'danger' ||
        recipe.porcentajeStock == 0 ||
        (recipe.porcentajeStock == null && (recipe.esCocinable ?? false) == false);
  }

  /// True solo cuando el “peligro” es por falta de stock (no por intolerancias).
  static bool isDangerPorStock(Recipe recipe) {
    return recipe.porcentajeStock == 0 ||
        (recipe.porcentajeStock == null && (recipe.esCocinable ?? false) == false);
  }
}

/// Tarjeta de receta en formato lista.
/// Con [showSemaforo] true (p. ej. planificador) muestra color y % de stock.
/// Con [showSemaforo] false (listado/galería general) no muestra semáforo, según estrategia.
class RecipeSemaphoreTile extends StatelessWidget {
  const RecipeSemaphoreTile({
    super.key,
    required this.recipe,
    this.subtitle,
    this.onTap,
    this.showSemaforo = true,
    this.enPlanificador = false,
  });

  final Recipe recipe;
  final Widget? subtitle;
  final VoidCallback? onTap;
  /// Si false, no se muestra semáforo ni % (listado general). Si true, se muestra (planificador).
  final bool showSemaforo;
  /// Si true, muestra icono de "en planificador" (evitar volver a añadir hasta pasar a lista).
  final bool enPlanificador;

  @override
  Widget build(BuildContext context) {
    final semaforoColor = showSemaforo ? RecipeSemaforo.color(recipe) : Colors.grey;
    final stockColor = showSemaforo ? RecipeSemaforo.colorSoloStock(recipe) : Colors.grey;
    final theme = Theme.of(context);
    final enListaCompra = showSemaforo && recipe.estadoDisponibilidadCompleta == 'en_camino';
    final imageUrl = RecipeService().recipeImageUrl(recipe.imagenUrl);

    Widget leadingIcon = CircleAvatar(
      backgroundColor: imageUrl != null ? Colors.transparent : semaforoColor.withOpacity(0.2),
      backgroundImage: imageUrl != null
          ? CachedNetworkImageProvider(imageUrl)
          : null,
      onBackgroundImageError: imageUrl != null ? (_, __) {} : null,
      child: imageUrl == null
          ? Icon(
              enListaCompra ? Icons.shopping_cart : (showSemaforo ? Icons.circle : Icons.restaurant),
              color: semaforoColor,
              size: showSemaforo ? (enListaCompra ? 20 : 12) : 20,
            )
          : null,
    );
    if (enListaCompra) {
      leadingIcon = Tooltip(
        message: 'Ingredientes en lista de compra',
        child: leadingIcon,
      );
    }

    Widget? trailing;
    if (enPlanificador || (showSemaforo && (recipe.porcentajeStock != null || enListaCompra))) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enPlanificador)
            Tooltip(
              message: 'En el planificador. Pasa los ingredientes a una lista de compra o quítala desde Cocina.',
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.event_note,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (showSemaforo && (recipe.porcentajeStock != null || enListaCompra))
            Text(
              enListaCompra ? 'En lista de compra' : 'Stock: ${recipe.porcentajeStock}%',
              style: TextStyle(
                color: enListaCompra ? semaforoColor : stockColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      );
    }
    return ListTile(
      leading: leadingIcon,
      title: Text(recipe.titulo),
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
