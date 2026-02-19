import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/contenedor.dart';
import '../models/lista_compra.dart';
import '../services/shopping_service.dart';
import '../services/stock_service.dart';
import '../state/kitchen_state.dart';
import '../widgets/main_layout.dart';

/// Pantalla de listas de compra con pestañas (ej. Mercadona, Carnicería).
/// Permite marcar ítems completados/pendientes y finalizar compra (mover al inventario).
/// [initialListaId] abre directamente la pestaña de esa lista si existe.
class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key, this.initialListaId});

  final int? initialListaId;

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  Future<List<ListaCompraCabecera>>? _listasFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool _listaTieneCompletados(ListaCompraCabecera lista) {
    return lista.items.any((i) =>
        (i.estado == 'completado' || i.completado == true) &&
        i.estado != 'procesado');
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _listasFuture = context.read<ShoppingService>().getListas();
    });
  }

  Future<void> _finalizarCompra(
    BuildContext context,
    ListaCompraCabecera lista,
    ShoppingService shoppingService,
  ) async {
    final completados = lista.items
        .where((i) =>
            i.estado == 'completado' || i.completado == true)
        .where((i) => i.estado != 'procesado')
        .toList();
    if (completados.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marca al menos un producto como comprado para finalizar.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    List<Contenedor> contenedores;
    try {
      contenedores = await StockService().fetchContenedores(hogarId: lista.hogarId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar contenedores: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (contenedores.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crea al menos un contenedor en Despensa para poder finalizar la compra.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final defaultContenedorId = completados.first.contenedorId ?? contenedores.first.id;
    final lineas = completados
        .map((item) => ProcesarCompraLinea(
              listaCompraItemId: item.id,
              contenedorId: item.contenedorId ?? defaultContenedorId,
              cantidad: item.cantidadCompra > 0 ? item.cantidadCompra : item.cantidad,
            ))
        .toList();
    try {
      final result = await shoppingService.procesarCompra(lineas);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
        context.read<KitchenState>().refreshAfterPurchase();
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
    final shoppingService = context.watch<ShoppingService>();
    _listasFuture ??= shoppingService.getListas();
    return FutureBuilder<List<ListaCompraCabecera>>(
        future: _listasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(LucideIcons.refreshCw),
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.listChecks,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay listas de compra',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Añade productos desde el Embudo de compra o crea listas en la web.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (_tabController == null ||
              _tabController!.length != listas.length) {
            _tabController?.dispose();
            final initialIndex = widget.initialListaId != null
                ? listas.indexWhere((l) => l.id == widget.initialListaId).clamp(0, listas.length - 1)
                : 0;
            final controller = TabController(
              length: listas.length,
              initialIndex: initialIndex >= 0 ? initialIndex : 0,
              vsync: this,
            );
            controller.addListener(() => setState(() {}));
            _tabController = controller;
          }
          final currentIndex = _tabController!.index;
          final listaActual = currentIndex < listas.length
              ? listas[currentIndex]
              : null;
          final showFinalizar =
              listaActual != null && _listaTieneCompletados(listaActual);
          final listToFinalize = listaActual;

          return MainLayout(
            title: 'Listas de compra',
            actions: [
              if (showFinalizar && listToFinalize != null)
                IconButton(
                  tooltip: 'Finalizar compra',
                  icon: const Icon(LucideIcons.shoppingCart),
                  onPressed: () =>
                      _finalizarCompra(context, listToFinalize, shoppingService),
                ),
            ],
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: listas
                      .map((l) => Tab(
                            icon: const Icon(LucideIcons.list, size: 20),
                            text: l.titulo.isEmpty ? 'Lista ${l.id}' : l.titulo,
                          ))
                      .toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController!,
                    children: listas.map((lista) {
                      return _ListaTab(
                        key: ValueKey<int>(lista.id),
                        lista: lista,
                        shoppingService: shoppingService,
                        onRefresh: _refresh,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
  }
}

class _ListaTab extends StatelessWidget {
  const _ListaTab({
    super.key,
    required this.lista,
    required this.shoppingService,
    required this.onRefresh,
  });

  final ListaCompraCabecera lista;
  final ShoppingService shoppingService;
  final VoidCallback onRefresh;

  Future<void> _toggleItem(
    BuildContext context,
    ListaCompraItem item,
    bool newCompletado,
  ) async {
    try {
      await shoppingService.updateListItem(item.id, completado: newCompletado);
      onRefresh();
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
    final items = lista.items;

    return items.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.packageOpen,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin productos en esta lista',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isCompletado = item.completado == true ||
                  item.estado == 'completado';
              final isProcesado = item.estado == 'procesado';

              return _ListItemTile(
                item: item,
                isCompletado: isCompletado,
                isProcesado: isProcesado,
                onToggle: isProcesado
                    ? null
                    : (v) => _toggleItem(context, item, v),
              );
            },
          );
  }
}

class _ListItemTile extends StatelessWidget {
  const _ListItemTile({
    required this.item,
    required this.isCompletado,
    required this.isProcesado,
    this.onToggle,
  });

  final ListaCompraItem item;
  final bool isCompletado;
  final bool isProcesado;
  final void Function(bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    final nombre = item.producto?.nombre ?? 'Producto #${item.id}';
    final cantidad = item.cantidadCompra > 0
        ? item.cantidadCompra
        : item.cantidad;
    final unidad = item.unidadMedida?.abreviatura ?? item.unidadMedida?.nombre ?? '';
    final cantidadStr = unidad.isNotEmpty
        ? '${cantidad == cantidad.truncate() ? cantidad.toInt() : cantidad} $unidad'
        : cantidad.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isCompletado && !isProcesado
            ? Colors.green.shade50
            : (isProcesado
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null),
        borderRadius: BorderRadius.circular(12),
        border: isCompletado && !isProcesado
            ? Border.all(color: Colors.green.shade200, width: 1)
            : null,
      ),
      child: ListTile(
        leading: isProcesado
            ? Icon(LucideIcons.checkCircle,
                color: Theme.of(context).colorScheme.primary, size: 28)
            : Checkbox(
                value: isCompletado,
                onChanged: onToggle == null ? null : (v) => onToggle!(v ?? false),
                activeColor: Colors.green.shade700,
              ),
        title: Text(
          nombre,
          style: TextStyle(
            decoration: isCompletado ? TextDecoration.lineThrough : null,
            decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
            color: isProcesado
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        subtitle: Text(
          cantidadStr,
          style: TextStyle(
            decoration: isCompletado ? TextDecoration.lineThrough : null,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isProcesado
            ? Text(
                'En inventario',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              )
            : null,
      ),
    );
  }
}
