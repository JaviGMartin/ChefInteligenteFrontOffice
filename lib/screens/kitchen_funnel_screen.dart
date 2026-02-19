import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/lista_compra.dart';
import '../models/pendiente_compra.dart';
import '../models/recipe.dart';
import '../services/hogar_service.dart';
import '../services/recipe_service.dart';
import '../services/shopping_service.dart';
import '../state/kitchen_state.dart';
import '../widgets/main_layout.dart';
import '../widgets/recipe_semaforo.dart';
import 'elaboracion_screen.dart';
import 'recipe_detail_screen.dart';
import 'single_shopping_list_screen.dart';

/// Flujo: Cocina → Listas compra → Embudo → Compras. Catálogo en menú Recetas.
/// Estado centralizado en [KitchenState].
class KitchenFunnelScreen extends StatefulWidget {
  const KitchenFunnelScreen({super.key});

  @override
  State<KitchenFunnelScreen> createState() => _KitchenFunnelScreenState();
}

class _KitchenFunnelScreenState extends State<KitchenFunnelScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  static const int _tabCocina = 0;
  static const int _tabListasCompra = 1;
  static const int _tabEmbudo = 2;
  static const int _tabCompras = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    hogarActivoIdNotifier.addListener(_onHogarActivoChanged);
    // Cargar planificador al entrar: _onTabChanged solo se dispara al cambiar de pestaña,
    // no en la carga inicial con Cocina seleccionada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<KitchenState>().loadPlanificador();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    hogarActivoIdNotifier.removeListener(_onHogarActivoChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    final state = context.read<KitchenState>();
    if (_tabController.index == _tabCocina && !state.isLoadingPlanificador) {
      state.loadPlanificador();
    }
    if (_tabController.index == _tabEmbudo && state.shoppingPendientes == null && !state.isLoadingPendientes) {
      state.loadPendientes();
    }
  }

  void _onHogarActivoChanged() {
    if (mounted) {
      context.read<KitchenState>().loadPlanificador();
      context.read<KitchenState>().loadPendientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MainLayout(
      title: 'Planificador',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: primary,
            indicatorColor: primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Cocina'),
              Tab(text: 'Listas compra'),
              Tab(text: 'Embudo'),
              Tab(text: 'Compras'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CocinaTab(onNavigateToEmbudo: () => _tabController.animateTo(_tabEmbudo)),
                const _ListasCompraTab(),
                const _EmbudoTab(),
                const _ComprasTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña Cocina: semáforos reales. Botón "Enviar ingredientes faltantes a embudo".
class _CocinaTab extends StatelessWidget {
  const _CocinaTab({this.onNavigateToEmbudo});

  final VoidCallback? onNavigateToEmbudo;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<KitchenState>();

    if (state.isLoadingPlanificador && state.planificadorRecipes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.planificadorError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.planificadorError.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => state.loadPlanificador(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final recipes = state.planificadorRecipes ?? [];
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.calendarClock, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Aún no has elegido qué cocinar. Ve a Recetas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'En Recetas abre una receta y guárdala en el planificador; aquí verás la disponibilidad de ingredientes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilledButton.icon(
            onPressed: state.isLoadingPendientes ? null : () => _actualizarFaltantesYNavegar(context),
            icon: state.isLoadingPendientes ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.packageSearch, size: 20),
            label: const Text('Enviar ingredientes faltantes a embudo'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => state.loadPlanificador(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              children: [
                for (final recipe in recipes) ...[
                  if (RecipeSemaforo.isDangerPorStock(recipe)) _DangerBanner(),
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: RecipeSemaphoreTile(
                                  recipe: recipe,
                                  showSemaforo: true,
                                  subtitle: Text(
                                    recipe.averageRating != null ? 'Rating: ${recipe.averageRating}' : RecipeSemaforo.texto(recipe),
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(builder: (_) => RecipeDetailScreen(recipe: recipe, fromPlanificador: true)),
                                    );
                                    if (!context.mounted) return;
                                    context.read<KitchenState>().loadPlanificador();
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.error),
                                tooltip: 'Quitar del planificador',
                                onPressed: () => _CocinaTab._quitarDelPlanificador(context, recipe),
                              ),
                            ],
                          ),
                        ),
                        if (recipe.mensajeSalud != null || (recipe.ingredientesFaltantes?.isNotEmpty ?? false))
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _FaltantesYSalud(recipe: recipe),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: _IniciarElaboracionButton(recipe: recipe),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _quitarDelPlanificador(BuildContext context, Recipe recipe) async {
    try {
      await RecipeService().quitarDelPlanificador(recipe.id);
      if (context.mounted) {
        context.read<KitchenState>().loadPlanificador();
        context.read<KitchenState>().loadPendientes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${recipe.titulo}» quitada del planificador. Se han restado sus cantidades del embudo.'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _actualizarFaltantesYNavegar(BuildContext context) async {
    final state = context.read<KitchenState>();
    final recipes = state.planificadorRecipes ?? [];
    if (recipes.isEmpty) return;
    final ids = recipes.map((r) => r.id).toList();
    final shopping = context.read<ShoppingService>();
    try {
      final result = await shopping.bulkEnviarAPendientes(ids);
      await state.loadPendientes();
      if (!context.mounted) return;
      if (result.ingredientesAnadidos > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'Ingredientes faltantes actualizados en el Embudo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onNavigateToEmbudo?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'No se añadió ningún ingrediente. Las recetas ya estaban en el embudo o tienes todo el stock.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

/// Botón para iniciar elaboración. Verde: directo; Ámbar/Rojo: modal de confirmación.
class _IniciarElaboracionButton extends StatelessWidget {
  const _IniciarElaboracionButton({required this.recipe});

  final Recipe recipe;

  static bool _esListoParaCocinar(Recipe r) {
    return RecipeSemaforo.texto(r) == '¡Listo para cocinar!';
  }

  @override
  Widget build(BuildContext context) {
    final listo = _esListoParaCocinar(recipe);
    final color = RecipeSemaforo.color(recipe);

    return SizedBox(
      width: double.infinity,
      child: listo
          ? FilledButton.icon(
              onPressed: () => _navegarAElaboracion(context),
              icon: const Icon(Icons.restaurant_menu, size: 20),
              label: const Text('Iniciar elaboración'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: color,
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => _mostrarConfirmacionYNavigar(context),
              icon: Icon(Icons.warning_amber_rounded, size: 20, color: color),
              label: const Text('Iniciar con avisos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: color, width: 2),
              ),
            ),
    );
  }

  void _navegarAElaboracion(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElaboracionScreen(recipe: recipe),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<KitchenState>().loadPlanificador();
      }
    });
  }

  void _mostrarConfirmacionYNavigar(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Iniciar con avisos'),
        content: Text(
          recipe.ingredientesFaltantes?.isNotEmpty ?? false
              ? 'Te faltan algunos ingredientes o hay alertas de intolerancias. ¿Continuar de todos modos?'
              : 'Hay alertas de salud para esta receta. ¿Continuar de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navegarAElaboracion(context);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

/// Muestra ingredientes faltantes y aviso de intolerancias por receta.
/// Sin alertas de salud → verde. Peligro → rojo. Aviso → naranja.
class _FaltantesYSalud extends StatelessWidget {
  const _FaltantesYSalud({required this.recipe});

  final Recipe recipe;

  static bool _esSinAlertas(String? msg) {
    if (msg == null || msg.isEmpty) return true;
    final t = msg.trim().toLowerCase();
    return t == 'sin alertas de salud' || t == 'sin alertas';
  }

  static Color _colorSalud(String? mensajeSalud) {
    if (_esSinAlertas(mensajeSalud)) return Colors.green;
    final m = (mensajeSalud ?? '').toLowerCase();
    if (m.contains('peligro')) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faltantes = recipe.ingredientesFaltantes ?? [];
    final mensajeSalud = recipe.mensajeSalud?.trim();
    final textoSalud = _esSinAlertas(mensajeSalud) ? 'Sin alertas de salud' : (mensajeSalud ?? 'Sin alertas de salud');
    final colorSalud = _colorSalud(mensajeSalud);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (faltantes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Te faltan: ${faltantes.map((f) => '${f.nombre} (${f.cantidadFaltante.toStringAsFixed(f.cantidadFaltante == f.cantidadFaltante.roundToDouble() ? 0 : 1)} ${f.unidadAbrev})').join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _esSinAlertas(mensajeSalud) ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  size: 16,
                  color: colorSalud,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    textoSalud,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorSalud,
                      fontWeight: _esSinAlertas(mensajeSalud) ? null : FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text('Te faltan muchos ingredientes para esta receta.', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña Embudo (faltantes). Lista consolidada desde [KitchenState.shoppingPendientes].
class _EmbudoTab extends StatelessWidget {
  const _EmbudoTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<KitchenState>();
    final shopping = context.read<ShoppingService>();

    if (state.isLoadingPendientes && state.shoppingPendientes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.pendientesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.pendientesError.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => state.loadPendientes(), icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final list = state.shoppingPendientes ?? [];
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text('No hay ingredientes en el embudo', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'En "Cocina" pulsa "Enviar ingredientes faltantes a embudo" para traer aquí lo que falta para tus recetas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => state.loadPendientes(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final p = list[index];
          return Dismissible(
            key: ValueKey<int>(p.id),
            direction: DismissDirection.startToEnd,
            background: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.add_shopping_cart, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text('Añadir rápido', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              try {
                await shopping.distribuirPendiente(p.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${p.displayNombre}» añadido a la lista.'), behavior: SnackBarBehavior.floating));
                  context.read<KitchenState>().loadPendientes();
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
              }
              return false;
            },
            child: ListTile(
              title: Text(p.displayNombre, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.cantidadTexto),
                  if (p.textoOrigenes != null && p.textoOrigenes!.isNotEmpty)
                    Text(
                      p.textoOrigenes!,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
              onTap: () => _abrirModalLista(context, p, shopping, state),
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirModalLista(BuildContext context, PendienteCompra p, ShoppingService shopping, KitchenState state) async {
    List<ListaCompraCabecera> listas;
    try {
      listas = await shopping.getListas();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    if (!context.mounted) return;
    final result = await showModalBottomSheet<List<dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ModalSeleccionLista(pendiente: p, listas: listas),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final listaId = result[0] as int;
    double? cantidadCompra;
    if (result.length > 1 && result[1] != null) {
      final v = result[1];
      if (v is num) cantidadCompra = v.toDouble();
      else if (v is String) cantidadCompra = double.tryParse(v.replaceAll(',', '.'));
    }
    final productoId = result.length > 2 ? result[2] as int? : null;
    final unidadMedidaId = result.length > 3 ? result[3] as int? : null;
    try {
      await shopping.distribuirPendiente(
        p.id,
        listaDestinoId: listaId,
        productoId: productoId ?? p.productoId,
        cantidadCompra: cantidadCompra,
        unidadMedidaId: unidadMedidaId ?? p.unidadMedidaId,
      );
      if (context.mounted) {
        final nombre = p.producto != null ? (p.producto!.marca?.isNotEmpty == true ? '${p.producto!.nombre} (${p.producto!.marca})' : p.producto!.nombre) : p.displayNombre;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«$nombre» añadido a la lista.'), behavior: SnackBarBehavior.floating));
        state.loadPendientes();
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }
}

class _ModalSeleccionLista extends StatefulWidget {
  const _ModalSeleccionLista({required this.pendiente, required this.listas});

  final PendienteCompra pendiente;
  final List<ListaCompraCabecera> listas;

  @override
  State<_ModalSeleccionLista> createState() => _ModalSeleccionListaState();
}

class _ModalSeleccionListaState extends State<_ModalSeleccionLista> {
  late TextEditingController _cantidadController;
  List<ProductoSimple>? _productos;
  List<UnidadMedidaCompleta>? _unidades;
  int? _productoSeleccionadoId;
  int? _unidadSeleccionadaId;
  bool _cargandoProductos = false;
  bool _cargandoUnidades = false;
  String? _errorProductos;
  String? _errorUnidades;

  @override
  void initState() {
    super.initState();
    final pendiente = widget.pendiente;
    _cantidadController = TextEditingController(
      text: pendiente.cantidadCompra == pendiente.cantidadCompra.truncateToDouble()
          ? pendiente.cantidadCompra.toInt().toString()
          : pendiente.cantidadCompra.toString(),
    );
    _productoSeleccionadoId = pendiente.productoId;
    _unidadSeleccionadaId = pendiente.unidadMedidaId;
    _cargarProductos();
    _cargarUnidades();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargandoProductos = true);
    try {
      final shopping = context.read<ShoppingService>();
      final productos = await shopping.getProductosPorIngrediente(widget.pendiente.ingredienteId);
      if (mounted) {
        setState(() {
          _productos = productos;
          _cargandoProductos = false;
          _errorProductos = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorProductos = e.toString().replaceFirst('Exception: ', '');
          _cargandoProductos = false;
        });
      }
    }
  }

  Future<void> _cargarUnidades() async {
    setState(() => _cargandoUnidades = true);
    try {
      final shopping = context.read<ShoppingService>();
      final todasUnidades = await shopping.getUnidadesMedida();
      // Filtrar solo unidades del mismo tipo que la unidad actual
      List<UnidadMedidaCompleta> unidadesFiltradas = todasUnidades;
      if (widget.pendiente.unidadMedidaId != null) {
        final unidadActual = todasUnidades.firstWhere(
          (u) => u.id == widget.pendiente.unidadMedidaId,
          orElse: () => todasUnidades.first,
        );
        final tipoActual = unidadActual.tipo;
        unidadesFiltradas = todasUnidades.where((u) => u.tipo == tipoActual).toList();
      }
      if (mounted) {
        setState(() {
          _unidades = unidadesFiltradas;
          _cargandoUnidades = false;
          _errorUnidades = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorUnidades = e.toString().replaceFirst('Exception: ', '');
          _cargandoUnidades = false;
        });
      }
    }
  }

  void _onTapLista(int listaId) {
    final cantidadText = _cantidadController.text.trim();
    final cantidad = double.tryParse(cantidadText.replaceAll(',', '.'));
    Navigator.of(context).pop(<dynamic>[
      listaId,
      cantidad ?? widget.pendiente.cantidadCompra,
      _productoSeleccionadoId,
      _unidadSeleccionadaId,
    ]);
  }

  /// Muestra producto (nombre + marca) si existe; si no, ingrediente. Alineado con backend pendientes.
  static String _productoOTIngredienteTexto(PendienteCompra p) {
    if (p.producto != null) {
      final nombre = p.producto!.nombre;
      final marca = p.producto!.marca?.trim();
      final parte = marca != null && marca.isNotEmpty ? '$nombre ($marca)' : nombre;
      return '$parte · ${p.cantidadTexto}';
    }
    return '${p.displayNombre} · ${p.cantidadTexto}';
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = widget.pendiente;
    final listas = widget.listas;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Añadir a lista', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Ingrediente: ${pendiente.displayNombre}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              // Selector de producto
              if (_cargandoProductos)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorProductos != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_errorProductos!, style: TextStyle(color: Colors.red, fontSize: 12)),
                )
              else if (_productos != null && _productos!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: _productoSeleccionadoId,
                    items: _productos!.map((p) {
                      return DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(p.displayNombre, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _productoSeleccionadoId = val),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No hay productos para este ingrediente. Se añadirá como ingrediente genérico.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Campo cantidad
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _cantidadController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cantidad a comprar',
                    hintText: _unidades != null && _unidadSeleccionadaId != null
                        ? 'En ${_unidades!.firstWhere((u) => u.id == _unidadSeleccionadaId, orElse: () => _unidades!.first).abreviatura ?? ''}'
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              // Selector de unidad
              if (_cargandoUnidades)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorUnidades != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_errorUnidades!, style: TextStyle(color: Colors.red, fontSize: 12)),
                )
              else if (_unidades != null && _unidades!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Unidad de medida',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: _unidadSeleccionadaId,
                    items: _unidades!.map((u) {
                      return DropdownMenuItem<int>(
                        value: u.id,
                        child: Text(
                          u.abreviatura?.isNotEmpty == true
                              ? '${u.nombre} (${u.abreviatura})'
                              : u.nombre,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _unidadSeleccionadaId = val),
                  ),
                ),
              Expanded(
                child: listas.isEmpty
                    ? Center(child: Text('No tienes listas activas. Crea una en la web.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: listas.length,
                        itemBuilder: (context, index) {
                          final lista = listas[index];
                          return ListTile(
                            leading: Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                            title: Text(lista.titulo),
                            subtitle: Text('${lista.items.length} ítems'),
                            onTap: () => _onTapLista(lista.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pestaña Listas compra: subpestañas Activas y Archivadas. Crear/archivar en activas; solo borrar en archivadas.
class _ListasCompraTab extends StatefulWidget {
  const _ListasCompraTab();

  @override
  State<_ListasCompraTab> createState() => _ListasCompraTabState();
}

class _ListasCompraTabState extends State<_ListasCompraTab> with TickerProviderStateMixin {
  late TabController _subTabController;
  Future<List<ListaCompraCabecera>>? _listasActivasFuture;
  Future<List<ListaCompraCabecera>>? _listasPendientesFuture;
  Future<List<ListaCompraCabecera>>? _listasArchivadasFuture;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listasActivasFuture ??= context.read<ShoppingService>().getListas(archivada: false);
    _listasPendientesFuture ??= context.read<ShoppingService>().getListas(archivada: false, pendienteProcesar: true);
    _listasArchivadasFuture ??= context.read<ShoppingService>().getListas(archivada: true);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.microtask(() {
      if (mounted) {
        setState(() {
          _listasActivasFuture = context.read<ShoppingService>().getListas(archivada: false);
          _listasPendientesFuture = context.read<ShoppingService>().getListas(archivada: false, pendienteProcesar: true);
          _listasArchivadasFuture = context.read<ShoppingService>().getListas(archivada: true);
        });
      }
    });
  }

  Future<void> _refreshActivas() async {
    if (!mounted) return;
    await Future.microtask(() {
      if (mounted) {
        setState(() => _listasActivasFuture = context.read<ShoppingService>().getListas(archivada: false));
      }
    });
  }

  Future<void> _refreshPendientes() async {
    if (!mounted) return;
    await Future.microtask(() {
      if (mounted) {
        setState(() => _listasPendientesFuture = context.read<ShoppingService>().getListas(archivada: false, pendienteProcesar: true));
      }
    });
  }

  Future<void> _refreshArchivadas() async {
    if (!mounted) return;
    await Future.microtask(() {
      if (mounted) {
        setState(() => _listasArchivadasFuture = context.read<ShoppingService>().getListas(archivada: true));
      }
    });
  }

  static String _formatearFecha(String? fechaPrevista) {
    if (fechaPrevista == null || fechaPrevista.isEmpty) return 'Sin fecha';
    final parts = fechaPrevista.split('-');
    if (parts.length != 3) return fechaPrevista;
    final y = parts[0], m = parts[1], d = parts[2];
    return '$d/$m/$y';
  }

  Future<void> _crearNuevaLista(BuildContext context) async {
    final tituloController = TextEditingController();
    final fechaController = TextEditingController();
    DateTime? fechaSeleccionada;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nueva lista de compra'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: tituloController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor o nombre',
                        hintText: 'Ej: Mercadona, Carrefour',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fechaController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha prevista',
                        hintText: 'Opcional',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (fecha != null) {
                          setDialogState(() {
                            fechaSeleccionada = fecha;
                            fechaController.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (tituloController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre no puede estar vacío.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true && tituloController.text.trim().isNotEmpty && mounted) {
      try {
        final shopping = context.read<ShoppingService>();
        final fechaPrevista = fechaSeleccionada != null
            ? '${fechaSeleccionada!.year}-${fechaSeleccionada!.month.toString().padLeft(2, '0')}-${fechaSeleccionada!.day.toString().padLeft(2, '0')}'
            : null;
        await shopping.crearLista(tituloController.text.trim(), fechaPrevista: fechaPrevista);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lista "${tituloController.text.trim()}" creada.'), behavior: SnackBarBehavior.floating),
          );
          await _refresh();
        }
      } catch (e) {
        if (mounted) {
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
    tituloController.dispose();
    fechaController.dispose();
  }

  Future<void> _archivarLista(BuildContext context, ListaCompraCabecera lista) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar lista'),
        content: Text('¿Archivar "${lista.titulo}"? Saldrá del listado activo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archivar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ShoppingService>().archivarLista(lista.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista "${lista.titulo}" archivada.'), behavior: SnackBarBehavior.floating),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
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

  Future<void> _eliminarLista(BuildContext context, ListaCompraCabecera lista) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar definitivamente "${lista.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ShoppingService>().eliminarLista(lista.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista "${lista.titulo}" eliminada.'), behavior: SnackBarBehavior.floating),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
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
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _subTabController,
          labelColor: primary,
          indicatorColor: primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Pend. procesar'),
            Tab(text: 'Archivadas'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _ListasActivasView(
                listasFuture: _listasActivasFuture,
                onRefresh: _refresh,
                onRefreshActivas: _refreshActivas,
                crearNuevaLista: _crearNuevaLista,
                archivarLista: _archivarLista,
                formatearFecha: _formatearFecha,
              ),
              _ListasPendientesProcesarView(
                listasFuture: _listasPendientesFuture,
                onRefresh: _refresh,
                onRefreshPendientes: _refreshPendientes,
                formatearFecha: _formatearFecha,
              ),
              _ListasArchivadasView(
                listasFuture: _listasArchivadasFuture,
                onRefresh: _refreshArchivadas,
                eliminarLista: _eliminarLista,
                formatearFecha: _formatearFecha,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vista de listas activas: crear, archivar, sin borrar.
class _ListasActivasView extends StatelessWidget {
  const _ListasActivasView({
    required this.listasFuture,
    required this.onRefresh,
    required this.onRefreshActivas,
    required this.crearNuevaLista,
    required this.archivarLista,
    required this.formatearFecha,
  });

  final Future<List<ListaCompraCabecera>>? listasFuture;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRefreshActivas;
  final Future<void> Function(BuildContext) crearNuevaLista;
  final Future<void> Function(BuildContext, ListaCompraCabecera) archivarLista;
  final String Function(String?) formatearFecha;

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingService>();
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: listasFuture ?? shopping.getListas(archivada: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () => onRefresh(), icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        final listas = snapshot.data ?? [];
        if (listas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.listChecks, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No hay listas de compra',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea una lista y asígnala a un proveedor (ej. Mercadona, Carrefour).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => crearNuevaLista(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear lista'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: listas.length + 1,
            itemBuilder: (context, index) {
              if (index == listas.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => crearNuevaLista(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear nueva lista'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                );
              }
              final lista = listas[index];
              final puedeArchivar = lista.items.every((i) =>
                  i.estado == 'procesado' || i.estado == 'no_disponible');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(LucideIcons.listChecks, color: Theme.of(context).colorScheme.primary),
                  title: Text(lista.titulo),
                  subtitle: Text(formatearFecha(lista.fechaPrevista)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (puedeArchivar)
                        IconButton(
                          icon: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.outline),
                          tooltip: 'Archivar lista',
                          onPressed: () => archivarLista(context, lista),
                        ),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => SingleShoppingListScreen(listaId: lista.id),
                      ),
                    );
                    if (result == true && context.mounted) {
                      await onRefreshActivas();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Vista de listas pendientes de procesar (ya pasaron por caja; el usuario puede abrirlas y pulsar "Procesar").
class _ListasPendientesProcesarView extends StatelessWidget {
  const _ListasPendientesProcesarView({
    required this.listasFuture,
    required this.onRefresh,
    required this.onRefreshPendientes,
    required this.formatearFecha,
  });

  final Future<List<ListaCompraCabecera>>? listasFuture;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRefreshPendientes;
  final String Function(String?) formatearFecha;

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingService>();
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: listasFuture ?? shopping.getListas(archivada: false, pendienteProcesar: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        final listas = snapshot.data ?? [];
        if (listas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.package, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No hay listas pendientes de procesar',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Al pulsar "Finalizar compra" en una lista activa, aparecerá aquí. '
                    'Luego podrás indicar caducidad y ubicación.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: listas.length,
            itemBuilder: (context, index) {
              final lista = listas[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(LucideIcons.package, color: Theme.of(context).colorScheme.primary),
                  title: Text(lista.titulo),
                  subtitle: Text(formatearFecha(lista.fechaPrevista)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => SingleShoppingListScreen(
                          listaId: lista.id,
                          pendienteDeProcesar: true,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      await onRefreshPendientes();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Vista de listas archivadas: solo listar y borrar (no crear, no archivar).
class _ListasArchivadasView extends StatefulWidget {
  const _ListasArchivadasView({
    required this.listasFuture,
    required this.onRefresh,
    required this.eliminarLista,
    required this.formatearFecha,
  });

  final Future<List<ListaCompraCabecera>>? listasFuture;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BuildContext, ListaCompraCabecera) eliminarLista;
  final String Function(String?) formatearFecha;

  @override
  State<_ListasArchivadasView> createState() => _ListasArchivadasViewState();
}

class _ListasArchivadasViewState extends State<_ListasArchivadasView> {
  late Future<List<ListaCompraCabecera>>? _localListasFuture;

  @override
  void initState() {
    super.initState();
    _localListasFuture = widget.listasFuture;
  }

  Future<void> _localRefresh() async {
    if (!mounted) return;
    final shopping = context.read<ShoppingService>();
    setState(() {
      _localListasFuture = shopping.getListas(archivada: true);
    });
    // Esperamos a que se complete la carga
    await _localListasFuture;
  }

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingService>();
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: _localListasFuture ?? shopping.getListas(archivada: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () => _localRefresh(), icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        final listas = snapshot.data ?? [];
        if (listas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.archive, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No hay listas archivadas',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las listas que archives aparecerán aquí. Solo desde aquí puedes eliminarlas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _localRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: listas.length,
            itemBuilder: (context, index) {
              final lista = listas[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(LucideIcons.archive, color: Theme.of(context).colorScheme.outline),
                  title: Text(lista.titulo),
                  subtitle: Text(widget.formatearFecha(lista.fechaPrevista)),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                    tooltip: 'Eliminar lista',
                    onPressed: () => widget.eliminarLista(context, lista),
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SingleShoppingListScreen(listaId: lista.id, readOnly: true),
                      ),
                    );
                    // No refrescamos automáticamente para evitar setState durante build
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Pestaña Compras: listado de listas de compra; al tocar una se abre su contenido.
class _ComprasTab extends StatefulWidget {
  const _ComprasTab();

  @override
  State<_ComprasTab> createState() => _ComprasTabState();
}

class _ComprasTabState extends State<_ComprasTab> {
  Future<List<ListaCompraCabecera>>? _listasFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listasFuture ??= context.read<ShoppingService>().getListas();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _listasFuture = context.read<ShoppingService>().getListas();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingService>();
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: _listasFuture ?? shopping.getListas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final listas = snapshot.data ?? [];
        if (listas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shoppingCart, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No hay listas de compra',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea listas en la pestaña Listas compra.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: listas.length,
            itemBuilder: (context, index) {
              final lista = listas[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(LucideIcons.listChecks, color: Theme.of(context).colorScheme.primary),
                  title: Text(lista.titulo),
                  subtitle: Text('${lista.items.length} ítems'),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SingleShoppingListScreen(listaId: lista.id),
                      ),
                    );
                    if (!context.mounted) return;
                    context.read<KitchenState>().refreshAfterPurchase();
                    _refresh();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
