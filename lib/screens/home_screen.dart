import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lista_compra.dart';
import '../models/recipe.dart';
import '../services/hogar_service.dart';
import '../services/shopping_service.dart';
import '../services/stock_service.dart';
import '../state/kitchen_state.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';
import '../widgets/recipe_semaforo.dart';
import 'inventory/global_pantry_screen.dart';
import 'kitchen_funnel_screen.dart';
import 'recipe_detail_screen.dart';
import 'shopping_lists_screen.dart';

/// Pantalla Home (Fase 1 reestructuración): resumen y acciones rápidas.
/// - Puedes cocinar ahora
/// - Listas de compra pendientes
/// - Próximo en el plan
/// - Inventario
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<ListaCompraCabecera>>? _listasFuture;
  Future<List<dynamic>>? _contenedoresFuture; // List<Contenedor> from StockService
  bool _planificadorLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_planificadorLoaded) {
      _planificadorLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<KitchenState>().loadPlanificador();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _listasFuture = ShoppingService().getListas(archivada: false);
    _contenedoresFuture = _loadContenedores();
  }

  Future<List<dynamic>> _loadContenedores() async {
    final result = await HogarService().fetchHogares();
    final hogarId = result.hogarActivoId;
    if (hogarId == null) return [];
    return StockService().fetchContenedores(hogarId: hogarId);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _listasFuture = ShoppingService().getListas(archivada: false);
      _contenedoresFuture = _loadContenedores();
    });
    context.read<KitchenState>().loadPlanificador();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Inicio',
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        color: AppColors.brandGreen,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PuedesCocinarAhoraBlock(),
            const SizedBox(height: 20),
            _ListasPendientesBlock(listasFuture: _listasFuture, onRefresh: _refresh),
            const SizedBox(height: 20),
            _ProximoEnPlanBlock(),
            const SizedBox(height: 20),
            _InventarioBlock(contenedoresFuture: _contenedoresFuture),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PuedesCocinarAhoraBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final kitchenState = context.watch<KitchenState>();
    final recipes = kitchenState.planificadorRecipes ?? [];
    final cocinables = recipes.where((r) => r.esCocinable == true).toList();
    final isLoading = kitchenState.isLoadingPlanificador;

    if (isLoading) {
      return _SectionCard(
        title: 'Puedes cocinar ahora',
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen),
            ),
          ),
        ),
      );
    }

    if (cocinables.isEmpty) {
      return _SectionCard(
        title: 'Puedes cocinar ahora',
        actionLabel: 'Ver plan',
        onAction: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const KitchenFunnelScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Añade recetas al plan para ver aquí las que tienes listas para cocinar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final toShow = cocinables.take(5).toList();
    return _SectionCard(
      title: 'Puedes cocinar ahora (${cocinables.length})',
      actionLabel: toShow.length < cocinables.length ? 'Ver todas' : 'Ver plan',
      onAction: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KitchenFunnelScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: toShow
            .map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.titulo),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.brandGreen),
                onTap: () => _openRecipe(context, r),
              ),
            )
            .toList(),
      ),
    );
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe, fromPlanificador: true),
      ),
    );
  }
}

class _ListasPendientesBlock extends StatelessWidget {
  const _ListasPendientesBlock({
    required this.listasFuture,
    required this.onRefresh,
  });

  final Future<List<ListaCompraCabecera>>? listasFuture;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: listasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SectionCard(
            title: 'Listas de compra',
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen),
                ),
              ),
            ),
          );
        }
        final listas = snapshot.data ?? [];
        final activas = listas.where((l) => !l.archivada && !l.pendienteProcesar).toList();

        if (activas.isEmpty) {
          return _SectionCard(
            title: 'Listas de compra',
            actionLabel: 'Ver listas',
            onAction: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ShoppingListsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No tienes listas activas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        final summary = activas.map((l) => '${l.titulo} (${l.items.length})').join(', ');
        return _SectionCard(
          title: 'Listas de compra pendientes',
          actionLabel: 'Ver listas',
          onAction: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ShoppingListsScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}

class _ProximoEnPlanBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final kitchenState = context.watch<KitchenState>();
    final recipes = kitchenState.planificadorRecipes ?? [];
    final isLoading = kitchenState.isLoadingPlanificador;

    if (isLoading || recipes.isEmpty) {
      return _SectionCard(
        title: 'Próximo en tu plan',
        actionLabel: 'Ver plan',
        onAction: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const KitchenFunnelScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            recipes.isEmpty && !isLoading
                ? 'Añade recetas al planificador para ver la próxima.'
                : 'Cargando…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final primera = recipes.first;

    return _SectionCard(
      title: 'Próximo en tu plan',
      actionLabel: 'Ver plan',
      onAction: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KitchenFunnelScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(primera.titulo),
            subtitle: Text(RecipeSemaforo.texto(primera)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.brandBlue),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: primera, fromPlanificador: true),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventarioBlock extends StatelessWidget {
  const _InventarioBlock({required this.contenedoresFuture});

  final Future<List<dynamic>>? contenedoresFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: contenedoresFuture,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? (snapshot.data!.length) : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final label = isLoading
            ? 'Cargando…'
            : count == 0
                ? 'Sin contenedores'
                : '$count contenedores';

        return _SectionCard(
          title: 'Inventario',
          actionLabel: 'Ver inventario',
          onAction: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GlobalPantryScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandBlue,
                        ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
