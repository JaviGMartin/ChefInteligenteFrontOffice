import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../services/hogar_service.dart';
import '../services/recipe_service.dart';
import '../state/kitchen_state.dart';
import '../widgets/main_layout.dart';
import '../widgets/recipe_semaforo.dart';
import '../widgets/recipe_status_badge.dart';
import 'kitchen_funnel_screen.dart';
import 'create_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> with SingleTickerProviderStateMixin {
  late Future<List<Recipe>> _recipesFuture;
  late TabController _tabController;
  String? _misRecetasEstadoFilter;
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _recipesFuture = RecipeService().fetchRecipes();
    hogarActivoIdNotifier.addListener(_onHogarActivoChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    hogarActivoIdNotifier.removeListener(_onHogarActivoChanged);
    super.dispose();
  }

  void _onHogarActivoChanged() {
    if (mounted) {
      setState(() {
        _recipesFuture = RecipeService().fetchRecipes();
      });
    }
  }

  Future<void> _refreshRecipes() async {
    setState(() {
      _recipesFuture = RecipeService().fetchRecipes();
    });
    await _recipesFuture;
  }

  List<Recipe> _misRecetas(List<Recipe> all, int? currentUserId) {
    if (currentUserId == null) return [];
    return all.where((r) => r.userId == currentUserId).toList();
  }

  List<Recipe> _misRecetasFiltradasPorEstado(List<Recipe> misRecetas) {
    if (_misRecetasEstadoFilter == null) return misRecetas;
    if (_misRecetasEstadoFilter == 'publicada') {
      return misRecetas.where((r) => r.estado == 'publicada' || r.estado == 'aprobada').toList();
    }
    return misRecetas.where((r) => r.estado == _misRecetasEstadoFilter).toList();
  }

  List<Recipe> _comunidad(List<Recipe> all, int? currentUserId) {
    return all.where((r) => r.userId != currentUserId).toList();
  }

  Future<void> _crearReceta(BuildContext context) async {
    final recipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute<Recipe>(builder: (_) => const CreateRecipeScreen()),
    );
    if (recipe != null && mounted) {
      _refreshRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Recetas',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _crearReceta(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva receta'),
      ),
      child: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthService.userNotifier,
        builder: (context, authUser, _) {
          final currentUserId = authUser?.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ActionChip(
                  avatar: Icon(Icons.restaurant_menu, size: 18, color: Theme.of(context).colorScheme.primary),
                  label: const Text('Ver Planificador'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const KitchenFunnelScreen(),
                      ),
                    );
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Mis Recetas'),
                  Tab(text: 'Comunidad'),
                ],
              ),
              if (_tabController.index == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'Estado:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                      value: _misRecetasEstadoFilter,
                      hint: const Text('Todas'),
                      isExpanded: false,
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                        DropdownMenuItem<String?>(value: 'borrador', child: Text('Borrador')),
                        DropdownMenuItem<String?>(value: 'pendiente', child: Text('En revisión')),
                        DropdownMenuItem<String?>(value: 'publicada', child: Text('Publicada')),
                        DropdownMenuItem<String?>(value: 'rechazada', child: Text('Rechazada')),
                      ],
                      onChanged: (value) {
                        setState(() => _misRecetasEstadoFilter = value);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Recipe>>(
                  future: _recipesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final allRecipes = snapshot.data ?? [];
                    final misRecetas = _misRecetasFiltradasPorEstado(
                      _misRecetas(allRecipes, currentUserId),
                    );
                    final planificadorIds = context.watch<KitchenState>().planificadorRecipes?.map((r) => r.id).toSet() ?? <int>{};
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _RecipeTabList(
                          recipes: misRecetas,
                          showStatusBadge: true,
                          onRefresh: _refreshRecipes,
                          planificadorIds: planificadorIds,
                        ),
                        _RecipeTabList(
                          recipes: _comunidad(allRecipes, currentUserId),
                          showStatusBadge: true,
                          onRefresh: _refreshRecipes,
                          planificadorIds: planificadorIds,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeTabList extends StatelessWidget {
  const _RecipeTabList({
    required this.recipes,
    this.showStatusBadge = true,
    this.onRefresh,
    this.planificadorIds = const {},
  });

  final List<Recipe> recipes;
  final bool showStatusBadge;
  final Future<void> Function()? onRefresh;
  final Set<int> planificadorIds;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return Center(
        child: onRefresh != null
            ? RefreshIndicator(
                onRefresh: onRefresh!,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(child: Text('No hay recetas en esta pestaña.')),
                  ),
                ),
              )
            : const Text('No hay recetas en esta pestaña.'),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return RecipeSemaphoreTile(
          recipe: recipe,
          showSemaforo: false,
          enPlanificador: planificadorIds.contains(recipe.id),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recipe.averageRating != null)
                Text(
                  'Rating: ${recipe.averageRating}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (showStatusBadge)
                RecipeStatusBadge(estado: recipe.estado, compact: true),
            ],
          ),
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => RecipeDetailScreen(recipe: recipe),
              ),
            );
            onRefresh?.call();
          },
        );
      },
    ),
  );
  }
}
