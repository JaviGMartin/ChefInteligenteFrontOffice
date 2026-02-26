import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/contenedor.dart';
import '../theme/app_colors.dart';
import '../models/lista_compra.dart';
import '../services/shopping_service.dart';
import '../services/stock_service.dart';
import '../widgets/cantidad_dialog.dart';
import '../widgets/main_layout.dart';
import 'add_producto_to_lista_screen.dart';
import 'barcode_scanner_screen.dart';
import 'procesar_compra_screen.dart';

/// Pantalla para visualizar y gestionar UNA sola lista de compra.
/// [pendienteDeProcesar] true cuando se abre desde la pestaña "Pendientes de procesar" (muestra botón "Procesar").
class SingleShoppingListScreen extends StatefulWidget {
  const SingleShoppingListScreen({
    super.key,
    required this.listaId,
    this.readOnly = false,
    this.pendienteDeProcesar = false,
  });

  final int listaId;
  final bool readOnly;
  final bool pendienteDeProcesar;

  @override
  State<SingleShoppingListScreen> createState() => _SingleShoppingListScreenState();
}

class _SingleShoppingListScreenState extends State<SingleShoppingListScreen> with SingleTickerProviderStateMixin {
  Future<ListaCompraCabecera>? _listaFuture;
  String _busqueda = '';
  late TabController _tabController;
  final TextEditingController _eanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _enviarEan(int listaId, String ean) async {
    final normalized = ean.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return;
    final shopping = context.read<ShoppingService>();
    try {
      final item = await shopping.buscarItemPorEan(listaId, normalized);
      if (!mounted) return;
      final nombre = item.producto?.nombre ?? 'este producto';
      final esPendiente = item.estado == 'pendiente';

      if (esPendiente) {
        // Ya está en la lista como pendiente: añadir cantidad o marcar en carrito
        final accion = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Artículo en la lista'),
            content: Text(
              'Ya tienes «$nombre» en la lista. '
              '¿Quieres añadir más cantidad o marcarlo como en el carrito?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cantidad'),
                child: const Text('Añadir más cantidad'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'marcar'),
                child: const Text('Marcar en el carrito'),
              ),
            ],
          ),
        );
        if (accion == null || accion.isEmpty || !mounted) return;
        if (accion == 'cantidad') {
          await _showEditarCantidad(context, item);
        } else {
          await shopping.marcarPorEan(listaId, normalized);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto marcado en el carrito.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Ya está en el carrito (completado/procesado): ofrecer añadir otro igual
        final anadirOtro = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Artículo en el carrito'),
            content: Text(
              'Ya tienes este artículo en el carrito. ¿Quieres añadir otro igual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sí, añadir otro'),
              ),
            ],
          ),
        );
        if (anadirOtro != true || !mounted) return;
        final unidadLabel = item.formato?.trim().isNotEmpty == true
            ? item.formato!
            : (item.unidadMedida?.abreviatura ?? item.unidadMedida?.nombre ?? 'ud.');
        final result = await showDialog<double?>(
          context: context,
          builder: (ctx) => _AnadirCantidadDialog(unidadLabel: unidadLabel),
        );
        if (result == null || result <= 0 || !mounted) return;
        final nuevaCantidad = item.cantidad + result;
        try {
          await shopping.updateListItem(item.id, cantidad: nuevaCantidad);
          if (!mounted) return;
          _refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cantidad actualizada: ${nuevaCantidad.toStringAsFixed(nuevaCantidad == nuevaCantidad.roundToDouble() ? 0 : 1)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      _eanController.clear();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      // El código no está en la lista: buscar si existe en el catálogo y ofrecer añadirlo
      try {
        final producto = await shopping.buscarProductoPorEan(normalized);
        if (!mounted) return;
        final anadir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Producto no está en la lista'),
            content: Text(
              '«${producto.nombre}» no se encuentra en la lista de la compra. '
              '¿Quieres añadirlo y agregarlo al carro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sí, añadir y marcar en el carrito'),
              ),
            ],
          ),
        );
        if (anadir != true || !mounted) return;
        // Cargar formatos (pack/unidad) y unidades para elegir cantidad correcta (p. ej. pack 6 L).
        List<FormatoProveedor> formatos = [];
        List<UnidadMedidaCompleta> unidades = [];
        try {
          final results = await Future.wait([
            shopping.getPreciosProveedores(producto.id),
            shopping.getUnidadesMedida(),
          ]);
          formatos = results[0] as List<FormatoProveedor>;
          unidades = results[1] as List<UnidadMedidaCompleta>;
        } catch (_) {}
        if (!mounted) return;
        final productoSimple = ProductoSimple(
          id: producto.id,
          nombre: producto.nombre,
          ingredienteId: 0,
        );
        final result = await showDialog<(double, bool, int?, int?)>(
          context: context,
          builder: (ctx) => CantidadDialog(
            producto: productoSimple,
            formatos: formatos,
            unidades: unidades,
            initialCompletado: true,
            initialProductoProveedorId: producto.productoProveedorId,
          ),
        );
        if (result == null || !mounted) return;
        final (cantidad, completado, productoProveedorId, unidadMedidaId) = result;
        await shopping.addItemToLista(
          listaId,
          producto.id,
          cantidad,
          unidadMedidaId: unidadMedidaId,
          productoProveedorId: productoProveedorId,
          completado: completado,
        );
        _eanController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completado
                  ? 'Producto añadido a la lista y marcado en el carrito.'
                  : 'Producto añadido a la lista.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
      } catch (_) {
        if (!mounted) return;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listaFuture ??= _cargarLista();
  }

  Future<ListaCompraCabecera> _cargarLista() async {
    final svc = context.read<ShoppingService>();
    final listas = widget.readOnly
        ? await svc.getListas(archivada: true)
        : await svc.getListas(archivada: false, pendienteProcesar: widget.pendienteDeProcesar);
    final lista = listas.firstWhere(
      (l) => l.id == widget.listaId,
      orElse: () => throw Exception('Lista no encontrada'),
    );
    return lista;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _listaFuture = _cargarLista();
    });
  }

  bool _listaTieneCompletados(ListaCompraCabecera lista) {
    return lista.items.any((i) =>
        (i.estado == 'completado' || i.completado == true) &&
        i.estado != 'procesado');
  }

  List<ListaCompraItem> _itemsPendientes(ListaCompraCabecera lista) {
    return lista.items.where((i) => i.estado == 'pendiente').toList();
  }

  List<ListaCompraItem> _itemsProcesados(ListaCompraCabecera lista) {
    return lista.items
        .where((i) => i.estado == 'completado' || i.estado == 'procesado')
        .toList();
  }

  List<ListaCompraItem> _itemsDescartados(ListaCompraCabecera lista) {
    return lista.items.where((i) => i.estado == 'no_disponible').toList();
  }

  List<ListaCompraItem> _itemsFiltradosPorBusqueda(List<ListaCompraItem> items) {
    if (_busqueda.trim().isEmpty) return items;
    final q = _busqueda.trim().toLowerCase();
    return items.where((i) {
      final nombre = (i.producto?.nombre ?? '').toLowerCase();
      final marca = (i.producto?.marca ?? '').toLowerCase();
      return nombre.contains(q) || marca.contains(q);
    }).toList();
  }

  /// Abre un modal para editar la cantidad del ítem (y opcionalmente unidad). Solo para ítems pendientes.
  Future<void> _showEditarCantidad(BuildContext context, ListaCompraItem item) async {
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => _EditarCantidadDialog(item: item),
    );
    if (result == null || !mounted) return;
    final shopping = context.read<ShoppingService>();
    try {
      await shopping.updateListItem(item.id, cantidad: result);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cantidad actualizada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Navega a la pantalla de procesar compra (contenedor, cantidad, fecha caducidad por ítem).
  Future<void> _navegarAProcesarCompra(
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Marca al menos un producto como comprado para finalizar.'),
          backgroundColor: AppColors.brandGreen.withOpacity(0.7),
        ),
      );
      return;
    }

    List<Contenedor> contenedores;
    try {
      contenedores = await StockService().fetchContenedores(hogarId: lista.hogarId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar contenedores: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (contenedores.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Crea al menos un contenedor en Despensa para poder finalizar la compra.'),
          backgroundColor: AppColors.brandGreen.withOpacity(0.7),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProcesarCompraScreen(
          listaId: lista.id,
          hogarId: lista.hogarId,
        ),
      ),
    );
    if (refreshed == true) _refresh();
  }

  /// Finalizar compra (ya pasé por caja): marca la lista como pendiente de procesar y vuelve atrás.
  Future<void> _finalizarCompra(BuildContext context, ListaCompraCabecera lista) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar compra'),
        content: const Text(
          '¿Ya pasaste por caja? La lista pasará a "Pendientes de procesar". '
          'Cuando llegues a casa podrás indicar caducidad y ubicación desde esa sección.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, finalizar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ShoppingService>().marcarPendienteProcesar(lista.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lista pasada a Pendientes de procesar. Procesa cuando llegues a casa.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
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

  /// Navega a la pantalla para añadir un producto a la lista (Crear ítem).
  Future<void> _navegarACrearItem(BuildContext context, int listaId) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddProductoToListaScreen(listaId: listaId),
      ),
    );
    if (refreshed == true) _refresh();
  }

  /// Barra inferior cuando la lista está en "activas": solo Finalizar compra (deshabilitado si hay pendientes).
  Widget _buildBarFinalizarCompra(BuildContext context, ListaCompraCabecera lista) {
    final hayPendientes = _itemsPendientes(lista).isNotEmpty;
    return Tooltip(
      message: hayPendientes
          ? 'Marca todos como "en el carro" o descártalos antes de finalizar la compra.'
          : 'Ya pasaste por caja: la lista pasará a Pendientes de procesar.',
      child: FilledButton.icon(
        onPressed: hayPendientes ? null : () => _finalizarCompra(context, lista),
        icon: const Icon(LucideIcons.checkCircle),
        label: Text(hayPendientes ? 'Finalizar compra (hay pendientes)' : 'Finalizar compra'),
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
      ),
    );
  }

  /// Barra inferior cuando la lista está en "Pendientes de procesar": Procesar, Volver a activas, Archivar.
  Widget _buildBarPendienteDeProcesar(BuildContext context, ListaCompraCabecera lista, bool tieneCompletados) {
    final shopping = context.read<ShoppingService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tieneCompletados)
          FilledButton.icon(
            onPressed: () => _navegarAProcesarCompra(context, lista, shopping),
            icon: const Icon(LucideIcons.package),
            label: const Text('Procesar'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        if (tieneCompletados) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _volverAActivas(context, lista),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                label: const Text('Volver a activas'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _archivarListaDesdePendientes(context, lista),
                icon: const Icon(LucideIcons.archive, size: 18),
                label: const Text('Archivar lista'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _volverAActivas(BuildContext context, ListaCompraCabecera lista) async {
    try {
      await context.read<ShoppingService>().reactivarLista(lista.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lista vuelta a listas activas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _archivarListaDesdePendientes(BuildContext context, ListaCompraCabecera lista) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar lista'),
        content: const Text(
          '¿Archivar esta lista? Los artículos que aún estaban pendientes se marcarán como "no disponible". '
          'La lista pasará a archivadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archivar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ShoppingService>().archivarLista(lista.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lista "${lista.titulo}" archivada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingService>();

    return MainLayout(
      title: widget.readOnly ? 'Lista archivada (solo lectura)' : 'Lista de compra',
      child: FutureBuilder<ListaCompraCabecera>(
        future: _listaFuture,
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
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
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

          final lista = snapshot.data;
          if (lista == null) {
            return const Center(child: Text('Lista no encontrada'));
          }

          final tieneCompletados = _listaTieneCompletados(lista);

          return Column(
            children: [
              // Encabezado compacto: nombre lista, fecha y buscador más arriba para dejar espacio a artículos
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primera línea: nombre 50% | buscador 50%
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              lista.titulo,
                              style: Theme.of(context).textTheme.headlineSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (!widget.readOnly)
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Buscar',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (s) => setState(() => _busqueda = s),
                            ),
                          ),
                      ],
                    ),
                    // Segunda línea: fecha pegada al nombre, alineada a la izquierda
                    if (lista.fechaPrevista != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Fecha prevista: ${_formatearFechaString(lista.fechaPrevista!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    if (!widget.readOnly) ...[
                      const SizedBox(height: 4),
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(text: 'Pendientes (${_itemsPendientes(lista).length})'),
                          Tab(text: 'Procesados (${_itemsProcesados(lista).length})'),
                          Tab(text: 'Descartados (${_itemsDescartados(lista).length})'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: widget.readOnly
                    ? _buildSingleList(lista, lista.items)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSingleList(lista, _itemsFiltradosPorBusqueda(_itemsPendientes(lista)), isPendientes: true),
                          _buildSingleList(lista, _itemsFiltradosPorBusqueda(_itemsProcesados(lista)), isProcesados: true),
                          _buildSingleList(lista, _itemsFiltradosPorBusqueda(_itemsDescartados(lista)), isDescartados: true),
                        ],
                      ),
              ),
              if ((tieneCompletados || widget.pendienteDeProcesar) && !widget.readOnly)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: widget.pendienteDeProcesar
                        ? _buildBarPendienteDeProcesar(context, lista, tieneCompletados)
                        : _buildBarFinalizarCompra(context, lista),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSingleList(
    ListaCompraCabecera lista,
    List<ListaCompraItem> items, {
    bool isPendientes = false,
    bool isProcesados = false,
    bool isDescartados = false,
  }) {
    final shopping = context.read<ShoppingService>();
    final showAddTile = !widget.readOnly && isPendientes;
    final itemCount = (showAddTile ? 1 : 0) + items.length;
    final showEanField = !widget.readOnly && isPendientes;

    final listContent = RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (showAddTile && index == 0) {
            return ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              title: Text(
                'Añadir artículo a la lista',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => _navegarACrearItem(context, lista.id),
            );
          }
          final itemIndex = showAddTile ? index - 1 : index;
          final item = items[itemIndex];
                            final completado = item.estado == 'completado' ||
                                item.completado == true;
                            final procesado = item.estado == 'procesado';
                            final noDisponible = item.estado == 'no_disponible';

                            final estadoLabel = procesado
                                ? 'Procesado'
                                : noDisponible
                                    ? 'No disponible'
                                    : completado
                                        ? 'Completado'
                                        : 'Pendiente';
                            final estadoColor = procesado
                                ? Colors.grey
                                : noDisponible
                                    ? Colors.red
                                    : completado
                                        ? AppColors.brandGreen
                                        : AppColors.brandGreen.withOpacity(0.8);

                            final subtitulo = [
                              item.cantidadYEmpaquetado,
                              if ((item.producto?.marca ?? '').isNotEmpty)
                                item.producto!.marca!,
                            ].join(' · ');

                            final canEditarCantidad = isPendientes &&
                                !noDisponible &&
                                !procesado &&
                                !widget.readOnly;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              leading: Checkbox(
                                value: completado || procesado,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (procesado || noDisponible || widget.readOnly)
                                    ? null
                                    : (val) async {
                                        try {
                                          await shopping.updateListItem(
                                            item.id,
                                            completado: val ?? false,
                                          );
                                          _refresh();
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst('Exception: ', ''),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                              ),
                              title: InkWell(
                                onTap: canEditarCantidad
                                    ? () => _showEditarCantidad(context, item)
                                    : null,
                                child: Text(
                                  item.producto?.nombre ?? 'Producto desconocido',
                                  style: procesado || completado
                                      ? const TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                        )
                                      : null,
                                ),
                              ),
                              subtitle: InkWell(
                                onTap: canEditarCantidad
                                    ? () => _showEditarCantidad(context, item)
                                    : null,
                                child: Text(
                                  subtitulo.isEmpty ? '—' : subtitulo,
                                  style: procesado || completado
                                      ? const TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                        )
                                      : null,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(
                                      estadoLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: estadoColor,
                                      ),
                                    ),
                                    backgroundColor: estadoColor.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (!procesado && !widget.readOnly)
                                    (isDescartados && noDisponible) || (isProcesados && completado)
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.undo,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 22,
                                            ),
                                            tooltip: 'Volver a pendiente',
                                            onPressed: () async {
                                              try {
                                                await shopping.updateListItem(
                                                  item.id,
                                                  estado: 'pendiente',
                                                );
                                                _refresh();
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e.toString().replaceFirst('Exception: ', ''),
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            },
                                          )
                                        : isPendientes && !noDisponible
                                            ? IconButton(
                                                onPressed: () async {
                                                  try {
                                                    await shopping.updateListItem(
                                                      item.id,
                                                      estado: 'no_disponible',
                                                    );
                                                    _refresh();
                                                  } catch (e) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          e.toString().replaceFirst('Exception: ', ''),
                                                        ),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: Icon(
                                                  Icons.remove_shopping_cart,
                                                  size: 22,
                                                  color: Theme.of(context).colorScheme.outline,
                                                ),
                                                tooltip: 'No disponible',
                                              )
                                            : const SizedBox.shrink(),
                                  if (!widget.readOnly)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(context).colorScheme.error,
                                        size: 22,
                                      ),
                                      tooltip: 'Eliminar de la lista',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Eliminar de la lista'),
                                            content: Text(
                                              '¿Quitar "${item.producto?.nombre ?? 'este ítem'}" de la lista?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Theme.of(ctx).colorScheme.error,
                                                ),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true || !mounted) return;
                                        try {
                                          await shopping.deleteListItem(item.id);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Ítem eliminado de la lista.'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            _refresh();
                                          }
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst('Exception: ', ''),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            );
                        },
                        ),
    );

    if (showEanField) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _eanController,
                    decoration: const InputDecoration(
                      hintText: 'Código de barras (EAN)',
                      prefixIcon: Icon(Icons.qr_code_2),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => _enviarEan(lista.id, v),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: () async {
                    final ean = await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    );
                    if (ean != null && ean.trim().isNotEmpty && mounted) {
                      _eanController.text = ean;
                      await _enviarEan(lista.id, ean);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Escanear con la cámara',
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => _enviarEan(lista.id, _eanController.text),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Marcar'),
                ),
              ],
            ),
          ),
          Expanded(child: listContent),
        ],
      );
    }
    return listContent;
  }

  /// Formatea una fecha en formato ISO (YYYY-MM-DD) a DD/MM/YYYY.
  String _formatearFechaString(String fechaIso) {
    final d = DateTime.tryParse(fechaIso);
    if (d == null) return fechaIso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// Diálogo para añadir más cantidad al mismo ítem (ej. "¿Cuántos más?").
class _AnadirCantidadDialog extends StatefulWidget {
  const _AnadirCantidadDialog({required this.unidadLabel});

  final String unidadLabel;

  @override
  State<_AnadirCantidadDialog> createState() => _AnadirCantidadDialogState();
}

class _AnadirCantidadDialogState extends State<_AnadirCantidadDialog> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir cantidad'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: '¿Cuántos más? (${widget.unidadLabel})',
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(
              _controller.text.trim().replaceAll(',', '.'),
            );
            if (v != null && v > 0) {
              Navigator.pop(context, v);
            }
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

/// Diálogo para editar la cantidad de un ítem de la lista.
class _EditarCantidadDialog extends StatefulWidget {
  const _EditarCantidadDialog({required this.item});

  final ListaCompraItem item;

  @override
  State<_EditarCantidadDialog> createState() => _EditarCantidadDialogState();
}

class _EditarCantidadDialogState extends State<_EditarCantidadDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final c = widget.item.cantidad;
    _controller = TextEditingController(
      text: c == c.roundToDouble() ? c.toInt().toString() : c.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unidadLabel = (item.unidadMedida?.abreviatura ?? item.unidadMedida?.nombre ?? 'ud.').trim();
    return AlertDialog(
      title: Text(item.producto?.nombre ?? 'Editar cantidad'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Cantidad ($unidadLabel)',
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(
              _controller.text.trim().replaceAll(',', '.'),
            );
            if (v != null && v > 0) {
              Navigator.pop(context, v);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
