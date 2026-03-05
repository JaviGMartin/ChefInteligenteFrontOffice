import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/planificacion.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../services/planificacion_service.dart';
import '../services/recipe_service.dart';
import '../services/shopping_service.dart';
import '../state/kitchen_state.dart';
import '../theme/app_colors.dart';
import '../widgets/main_layout.dart';
import '../widgets/anadir_faltantes_dialog.dart';
import '../widgets/recipe_semaforo.dart';
import 'elaboracion_screen.dart';
import 'recipe_detail_screen.dart';
import 'purchase_funnel_screen.dart';
import 'single_shopping_list_screen.dart';

class CalendarPlannerScreen extends StatefulWidget {
  const CalendarPlannerScreen({super.key});

  @override
  State<CalendarPlannerScreen> createState() => _CalendarPlannerScreenState();
}

class _CalendarPlannerScreenState extends State<CalendarPlannerScreen> {
  static const List<Map<String, String>> _tomas = [
    {'key': 'desayuno', 'label': 'Desayuno'},
    {'key': 'media_manana', 'label': 'Media mañana'},
    {'key': 'comida', 'label': 'Comida'},
    {'key': 'merienda', 'label': 'Merienda'},
    {'key': 'cena', 'label': 'Cena'},
  ];

  final PlanificacionService _service = PlanificacionService();
  final RecipeService _recipeService = RecipeService();

  DateTime _weekStart = _startOfWeek(DateTime.now());
  bool _loading = true;
  String? _error;
  List<Planificacion> _items = [];
  List<Recipe> _recipes = [];
  bool _puedeEditarCalendario = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday; // 1 = lunes
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// "Semana del 2 de marzo al 8 de marzo de 2026"
  String _fmtSemanaDisplay(DateTime start, DateTime end) {
    final f = DateFormat('d \'de\' MMMM \'de\' y', 'es');
    return 'Semana del ${f.format(start)} al ${f.format(end)}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _weekStart;
      final to = _weekStart.add(const Duration(days: 6));
      final response = await _service.fetchPlanificaciones(from: from, to: to);
      final recetas = await _recipeService.fetchPlanificador();
      if (!mounted) return;
      setState(() {
        _items = response.list;
        _recipes = recetas;
        _puedeEditarCalendario = response.puedeEditarCalendario;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _crearPlanificacion({
    required int recetaId,
    required DateTime fecha,
    required String toma,
  }) async {
    try {
      await _service.crearPlanificacion(
        recetaId: recetaId,
        fecha: _fmt(fecha),
        toma: toma,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _eliminarPlanificacion(int id) async {
    try {
      await _service.eliminarPlanificacion(id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Mapa recetaId -> número de veces que aparece en la semana (para cantidades correctas).
  Map<int, int> _recetaCantidadesDeLaSemana() {
    final map = <int, int>{};
    for (final plan in _items) {
      if (plan.receta != null) {
        final id = plan.receta!.id;
        map[id] = (map[id] ?? 0) + 1;
      }
    }
    return map;
  }

  Future<void> _anadirFaltantesDeLaSemana() async {
    final recetaCantidades = _recetaCantidadesDeLaSemana();
    if (recetaCantidades.isEmpty) return;
    final recipeIds = recetaCantidades.keys.toList();
    final state = context.read<KitchenState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopping = ShoppingService();
    try {
      final result = await shopping.bulkEnviarAPendientes(
        recipeIds,
        recetaCantidades: recetaCantidades,
      );
      await state.loadPendientes();
      if (!mounted) return;
      final pendientes = state.shoppingPendientes ?? [];
      if (pendientes.isNotEmpty) {
        final dialogResult = await showModalBottomSheet<AnadirFaltantesDialogResult>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => AnadirFaltantesDialog(
            onRepartir: () => Navigator.of(ctx).pop(const AnadirFaltantesDialogResult.repartir()),
            onUnaLista: (proveedorId, fechaPrevista) =>
                Navigator.of(ctx).pop(AnadirFaltantesDialogResult.unaLista(proveedorId, fechaPrevista)),
            initialProveedorId: result.proveedorSugeridoId,
          ),
        );
        if (!mounted) return;
        if (dialogResult == null) return;
        if (dialogResult.repartir) {
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const PurchaseFunnelScreen()),
          );
          return;
        }
        if (dialogResult.proveedorId != null) {
          try {
            final distribucion = await shopping.distribuirPendientesPorPreferencia(
              preferenciaProveedorId: dialogResult.proveedorId!,
              pendienteIds: pendientes.map((p) => p.id).toList(),
              fechaPrevista: dialogResult.fechaPrevista,
            );
            await state.loadPendientes();
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${pendientes.length} ingrediente(s) añadidos según tu preferencia.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final listaPrincipalId = distribucion.listaPrincipalId;
              if (listaPrincipalId != null) {
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => SingleShoppingListScreen(listaId: listaPrincipalId),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          return;
        }
      }
      if (result.ingredientesAnadidos > 0 && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'Ingredientes añadidos a Ingredientes a productos.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'No hay ingredientes nuevos que añadir.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openSelector({
    required DateTime fecha,
    required String toma,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        if (_recipes.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('No tienes recetas en el planificador.'),
                  SizedBox(height: 8),
                  Text('Guarda recetas desde la pantalla de Recetas para poder planificarlas.'),
                ],
              ),
            ),
          );
        }
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _recipes.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return ListTile(
                  title: Text(recipe.titulo),
                  subtitle: recipe.authorName != null && recipe.authorName!.isNotEmpty
                      ? Text(recipe.authorName!)
                      : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _crearPlanificacion(
                      recetaId: recipe.id,
                      fecha: fecha,
                      toma: toma,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.userNotifier.value;
    if (user != null && !user.esPremiumOGold) {
      return MainLayout(
        title: 'Calendario',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'El calendario está disponible para usuarios Premium o Gold.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final end = _weekStart.add(const Duration(days: 6));
    return MainLayout(
      title: 'Calendario',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _weekStart = _weekStart.subtract(const Duration(days: 7));
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _fmtSemanaDisplay(_weekStart, end),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _weekStart = _weekStart.add(const Duration(days: 7));
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (!_puedeEditarCalendario)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Tu dietista gestiona este calendario. Puedes ver las recetas pero no modificarlas desde la app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          if (!_loading && _error == null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                onPressed: _anadirFaltantesDeLaSemana,
                icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                label: const Text('Añadir ingredientes faltantes a la compra'),
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final day = _weekStart.add(Duration(days: index));
                  return _DaySection(
                    date: day,
                    items: _items,
                    tomas: _tomas,
                    puedeEditar: _puedeEditarCalendario,
                    onAdd: (tomaKey) => _openSelector(fecha: day, toma: tomaKey),
                    onRemove: _eliminarPlanificacion,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.date,
    required this.items,
    required this.tomas,
    required this.puedeEditar,
    required this.onAdd,
    required this.onRemove,
  });

  final DateTime date;
  final List<Planificacion> items;
  final List<Map<String, String>> tomas;
  final bool puedeEditar;
  final void Function(String tomaKey) onAdd;
  final void Function(int id) onRemove;

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// "Lunes 2 de marzo de 2026"
  String _fmtDiaCompleto(DateTime d) {
    final s = DateFormat('EEEE d \'de\' MMMM \'de\' y', 'es').format(d);
    return s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
  }

  @override
  Widget build(BuildContext context) {
    final fechaKey = _fmt(date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmtDiaCompleto(date),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final toma in tomas) ...[
              _TomaRow(
                tomaLabel: toma['label'] ?? 'Toma',
                items: items.where((p) => p.fecha == fechaKey && p.toma == toma['key']).toList(),
                puedeEditar: puedeEditar,
                onAdd: () => onAdd(toma['key'] ?? ''),
                onRemove: onRemove,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Texto y color de stock/salud para una planificación (datos del backend).
/// Si los ingredientes faltantes están en lista de compra, se muestra "En lista de compra" como en el planificador.
({String text, Color color}) _stockSaludFromPlan(Planificacion plan) {
  if (plan.estadoDisponibilidadCompleta == 'en_camino') {
    return (text: 'En lista de compra', color: AppColors.brandBlue);
  }
  final p = plan.porcentajeStock;
  final cocinable = plan.esCocinable ?? false;
  final stockOK = p == 100 || cocinable;
  if (stockOK) {
    return (text: 'Con stock', color: AppColors.brandGreen);
  }
  if (p != null && p > 0 && p < 100) {
    return (text: 'Faltan ingredientes', color: AppColors.brandGreen.withOpacity(0.7));
  }
  if (p == 0 || (p == null && !cocinable)) {
    return (text: 'Sin existencias', color: Colors.red);
  }
  return (text: 'Sin datos', color: Colors.grey);
}

bool _esSinAlertas(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('sin alertas') || lower == 'ok';
}

class _TomaRow extends StatelessWidget {
  const _TomaRow({
    required this.tomaLabel,
    required this.items,
    required this.puedeEditar,
    required this.onAdd,
    required this.onRemove,
  });

  final String tomaLabel;
  final List<Planificacion> items;
  final bool puedeEditar;
  final VoidCallback onAdd;
  final void Function(int id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tomaLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (puedeEditar)
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Añadir receta',
              ),
          ],
        ),
        if (items.isEmpty)
          Text(
            'Sin recetas',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )
        else
          Column(
            children: [
              for (final plan in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(plan.receta?.titulo ?? 'Receta'),
                  subtitle: plan.receta != null
                      ? Builder(
                          builder: (context) {
                            final stock = _stockSaludFromPlan(plan);
                            final msg = plan.mensajeSalud?.trim();
                            final esAlerta = msg != null &&
                                msg.isNotEmpty &&
                                !_esSinAlertas(msg);
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: msg ?? stock.text,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          stock.text == 'En lista de compra'
                                              ? Icons.shopping_cart
                                              : Icons.circle,
                                          size: stock.text == 'En lista de compra' ? 16 : 8,
                                          color: stock.color,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          stock.text,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: stock.color,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (esAlerta)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        msg!.replaceFirst(RegExp(r'^(Alerta:?\s*)?(Aviso:?\s*)?', caseSensitive: false), ''),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.brandGreen.withOpacity(0.85),
                                              fontSize: 11,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        )
                      : null,
                  onTap: plan.receta != null
                      ? () {
                          final r = plan.receta!;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RecipeDetailScreen(
                                recipe: Recipe.minimalFromPlanificacionReceta(
                                  id: r.id,
                                  titulo: r.titulo,
                                  imagenUrl: r.imagenUrl,
                                ),
                                fromPlanificador: true,
                              ),
                            ),
                          );
                        }
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (plan.receta != null)
                        TextButton.icon(
                          onPressed: () => _enviarACocina(context, plan.receta!.id),
                          icon: const Icon(Icons.restaurant_menu, size: 18),
                          label: const Text('Enviar a Cocina'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (puedeEditar)
                        IconButton(
                          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                          onPressed: () => onRemove(plan.id),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static Future<void> _enviarACocina(BuildContext context, int recetaId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final recipe = await RecipeService().getRecipe(recetaId);
      if (!context.mounted) return;
      final listo = RecipeSemaforo.texto(recipe) == '¡Listo para cocinar!';
      void navegar() {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ElaboracionScreen(recipe: recipe),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<KitchenState>().loadPlanificador();
          }
        });
      }
      if (listo) {
        navegar();
        return;
      }
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Iniciar con avisos'),
          content: const Text(
            'Te faltan algunos ingredientes o hay alertas de intolerancias. ¿Continuar de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (context.mounted && continuar == true) navegar();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
