import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../services/recipe_service.dart';
import '../state/kitchen_state.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';
import '../widgets/recipe_semaforo.dart';
import '../widgets/recipe_status_badge.dart';
import 'edit_recipe_screen.dart';
import 'kitchen_funnel_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe, this.fromPlanificador = false});

  final Recipe recipe;
  final bool fromPlanificador;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;
  bool _loadingFullRecipe = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    // Siempre cargar receta completa para tener elaboraciones y datos frescos
    // (el index no incluye elaboraciones; el show sí).
    _loadFullRecipe();
  }

  Future<void> _loadFullRecipe() async {
    if (_loadingFullRecipe) return;
    setState(() => _loadingFullRecipe = true);
    try {
      final full = await RecipeService().getRecipe(_recipe.id);
      if (mounted) {
        setState(() {
          _recipe = full;
          _loadingFullRecipe = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFullRecipe = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los ingredientes: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.brandGreen.withOpacity(0.7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _canEdit(bool enPlanificador) {
    final uid = AuthService.userNotifier.value?.id;
    if (uid == null || _recipe.userId == null) return false;
    if (uid != _recipe.userId) return false;
    if (enPlanificador) return false;
    return _recipe.estado == 'borrador' ||
        _recipe.estado == 'rechazada' ||
        _recipe.estado == 'publicada' ||
        _recipe.estado == 'aprobada';
  }

  bool _canVolverABorrador(bool enPlanificador) {
    final uid = AuthService.userNotifier.value?.id;
    if (uid == null || _recipe.userId == null) return false;
    if (uid != _recipe.userId) return false;
    if (enPlanificador) return false;
    return _recipe.estado == 'pendiente';
  }

  bool _canDelete(bool enPlanificador) {
    final uid = AuthService.userNotifier.value?.id;
    if (uid == null || _recipe.userId == null) return false;
    if (uid != _recipe.userId) return false;
    if (enPlanificador) return false;
    return _recipe.estado == 'borrador' ||
        _recipe.estado == 'rechazada' ||
        _recipe.estado == 'pendiente';
  }

  bool _canSolicitarPublicacion(bool enPlanificador) {
    final uid = AuthService.userNotifier.value?.id;
    if (uid == null || _recipe.userId == null) return false;
    if (uid != _recipe.userId) return false;
    if (enPlanificador) return false;
    return _recipe.estado == 'borrador' || _recipe.estado == 'rechazada';
  }

  Future<void> _volverABorrador(BuildContext context) async {
    try {
      final updated = await RecipeService().volverABorrador(_recipe.id);
      if (context.mounted) {
        setState(() => _recipe = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receta vuelta a borrador. Puedes editarla y volver a solicitar publicación.'),
            backgroundColor: AppColors.brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _solicitarPublicacion(BuildContext context) async {
    try {
      final updated = await RecipeService().solicitarPublicacion(_recipe.id);
      if (context.mounted) {
        setState(() => _recipe = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receta enviada a revisión. Recibirás notificación cuando se evalúe.'),
            backgroundColor: AppColors.brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Añade la receta al planificador (sin enviar ingredientes al embudo; el usuario usa el botón en Cocina).
  Future<void> _anadirALaSemana(BuildContext context) async {
    try {
      await RecipeService().guardarEnPlanificador(_recipe.id);
      if (context.mounted) context.read<KitchenState>().loadPlanificador();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Añadida al planificador. En Cocina puedes enviar los ingredientes faltantes al embudo.',
            ),
            backgroundColor: AppColors.brandGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ver Planificador',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KitchenFunnelScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _enviarAPendientes(BuildContext context) async {
    try {
      await RecipeService().enviarAPendientes(_recipe.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ingredientes añadidos al embudo. La receta queda en tu lista de decisión.',
            ),
            backgroundColor: AppColors.brandGreen,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Ver Planificador',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KitchenFunnelScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        // Si el backend dice que ya tienes todos los ingredientes, mostrarlo como info (verde), no error
        final esTodosIngredientes = msg.contains('Tienes todos los ingredientes') ||
            msg.contains('todos los ingredientes');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: esTodosIngredientes ? AppColors.brandGreen : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmarBorrar(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar receta'),
        content: Text(
          '¿Seguro que quieres borrar «${_recipe.titulo}»? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await RecipeService().deleteRecipe(_recipe.id);
      if (context.mounted) {
        context.read<KitchenState>().loadPlanificador();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${_recipe.titulo}» borrada.'),
            backgroundColor: AppColors.brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final kitchen = context.watch<KitchenState>();
    if (kitchen.planificadorRecipes == null && !kitchen.isLoadingPlanificador) {
      WidgetsBinding.instance.addPostFrameCallback((_) => kitchen.loadPlanificador());
    }
    final enPlanificador = kitchen.planificadorRecipes?.any((r) => r.id == recipe.id) ?? false;
    final imageUrl = RecipeService().recipeImageUrl(recipe.imagenUrl);

    return MainLayout(
      title: recipe.titulo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            RecipeStatusBadge(estado: recipe.estado),
            const SizedBox(height: 12),
            if (widget.fromPlanificador)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Material(
                  color: RecipeSemaforo.color(recipe).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          RecipeSemaforo.texto(recipe) == '¡Listo para cocinar!' ||
                                  RecipeSemaforo.texto(recipe) == 'Listo para cocinar (con avisos)'
                              ? Icons.check_circle
                              : (RecipeSemaforo.texto(recipe) == 'Faltan algunos ingredientes'
                                  ? Icons.warning_amber_rounded
                                  : Icons.cancel),
                          color: RecipeSemaforo.color(recipe),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            RecipeSemaforo.texto(recipe),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: RecipeSemaforo.color(recipe),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (recipe.descripcion != null && recipe.descripcion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  recipe.descripcion!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            if (recipe.tiempoPreparacion != null || recipe.dificultad != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Wrap(
                  spacing: 16,
                  children: [
                    if (recipe.tiempoPreparacion != null)
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 18, color: Colors.white70),
                        label: Text('${recipe.tiempoPreparacion} min'),
                      ),
                    if (recipe.dificultad != null)
                      Chip(
                        label: Text(recipe.dificultad!),
                      ),
                    if (recipe.porcionesBase != null)
                      Chip(
                        label: Text('${recipe.porcionesBase} porciones'),
                      ),
                  ],
                ),
              ),
            if (recipe.herramientas != null && recipe.herramientas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Herramientas necesarias',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: recipe.herramientas!
                          .map((h) => Chip(
                                avatar: const Icon(Icons.restaurant_rounded, size: 18, color: Colors.white70),
                                label: Text(h),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Ingredientes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_loadingFullRecipe)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recipe.ingredientes.isEmpty)
              const Text('Sin ingredientes listados.')
            else
              ...recipe.ingredientes.map(
                (ing) {
                  final cantidadTexto = ing.cantidad != null && ing.unidadMedida != null
                      ? '${ing.cantidad} ${ing.unidadMedida!.abreviatura ?? ing.unidadMedida!.nombre}'
                      : '';
                  final nombreCompleto = cantidadTexto.isNotEmpty
                      ? '$cantidadTexto de ${ing.nombre}'
                      : ing.nombre;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(nombreCompleto)),
                      ],
                    ),
                  );
                },
              ),
            if (recipe.instrucciones != null && recipe.instrucciones!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              Text(
                'Elaboración',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                recipe.instrucciones!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if ((recipe.instrucciones == null || recipe.instrucciones!.isEmpty) &&
                recipe.elaboraciones != null &&
                recipe.elaboraciones!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              Text(
                'Elaboración',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...recipe.elaboraciones!.expand((elab) => [
                    if (elab.titulo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          elab.titulo,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ...elab.pasos.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key + 1}. ',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Expanded(child: Text(e.value.descripcion, style: Theme.of(context).textTheme.bodyLarge)),
                            ],
                          ),
                        )),
                  ]),
            ],
            const SizedBox(height: 24),
            if (_canEdit(enPlanificador))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<Recipe>(
                      MaterialPageRoute<Recipe>(
                        builder: (_) => EditRecipeScreen(recipe: recipe),
                      ),
                    );
                    if (updated != null && mounted) {
                      _loadFullRecipe();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    'publicada' == recipe.estado || 'aprobada' == recipe.estado
                        ? 'Solicitar corrección'
                        : 'Editar receta',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_canVolverABorrador(enPlanificador))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () => _volverABorrador(context),
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Volver a borrador'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_canSolicitarPublicacion(enPlanificador))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FilledButton.tonalIcon(
                  onPressed: () => _solicitarPublicacion(context),
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Solicitar publicación'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: enPlanificador ? null : () => _anadirALaSemana(context),
              icon: Icon(enPlanificador ? Icons.event_note : Icons.restaurant_menu),
              label: Text(enPlanificador ? 'Ya en el planificador' : 'Añadir al planificador'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (enPlanificador)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pasa los ingredientes a una lista de compra o quítala desde Planificador > Cocina.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (widget.fromPlanificador) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _enviarAPendientes(context),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Solo enviar faltantes al embudo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
            if (_canDelete(enPlanificador))
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton.icon(
                  onPressed: () => _confirmarBorrar(context),
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  label: Text(
                    'Borrar receta',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            if (widget.fromPlanificador) ...[
              const SizedBox(height: 16),
              Text(
                RecipeSemaforo.texto(recipe) == '¡Listo para cocinar!'
                    ? 'Tienes todos los ingredientes para esta receta.'
                    : 'Añade los ingredientes que te faltan al embudo de compra para tu hogar activo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RecipeSemaforo.texto(recipe) == '¡Listo para cocinar!'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
