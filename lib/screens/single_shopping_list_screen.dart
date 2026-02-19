import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/contenedor.dart';
import '../models/lista_compra.dart';
import '../services/shopping_service.dart';
import '../services/stock_service.dart';
import '../widgets/main_layout.dart';
import 'add_producto_to_lista_screen.dart';
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

class _SingleShoppingListScreenState extends State<SingleShoppingListScreen> {
  Future<ListaCompraCabecera>? _listaFuture;
  String _busqueda = '';

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

  List<ListaCompraItem> _itemsFiltrados(ListaCompraCabecera lista) {
    if (_busqueda.trim().isEmpty) return lista.items;
    final q = _busqueda.trim().toLowerCase();
    return lista.items.where((i) {
      final nombre = (i.producto?.nombre ?? '').toLowerCase();
      final marca = (i.producto?.marca ?? '').toLowerCase();
      return nombre.contains(q) || marca.contains(q);
    }).toList();
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
        const SnackBar(
          content: Text('Marca al menos un producto como comprado para finalizar.'),
          backgroundColor: Colors.orange,
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
        const SnackBar(
          content: Text('Crea al menos un contenedor en Despensa para poder finalizar la compra.'),
          backgroundColor: Colors.orange,
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
              // Encabezado: título en solitario, luego botón Crear ítem (compacto)
              Container(
                padding: const EdgeInsets.all(16),
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
                  children: [
                    Text(
                      lista.titulo,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (!widget.readOnly) const SizedBox(height: 4),
                    if (lista.fechaPrevista != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Fecha prevista: ${_formatearFechaString(lista.fechaPrevista!)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${lista.items.length} ítems',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (s) => setState(() => _busqueda = s),
                      ),
                    ],
                  ],
                ),
              ),
              // Lista de ítems
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: (widget.readOnly ? 0 : 1) + _itemsFiltrados(lista).length,
                    itemBuilder: (context, index) {
                      if (!widget.readOnly && index == 0) {
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
                      final itemIndex = widget.readOnly ? index : index - 1;
                      final item = _itemsFiltrados(lista)[itemIndex];
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
                                        ? Colors.green
                                        : Colors.amber;

                            final subtitulo = [
                              '${item.cantidad} ${item.unidadMedida?.abreviatura ?? ''}'.trim(),
                              if ((item.producto?.marca ?? '').isNotEmpty)
                                item.producto!.marca!,
                            ].join(' · ');

                            return ListTile(
                              leading: Checkbox(
                                value: completado || procesado,
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
                              title: Text(
                                item.producto?.nombre ?? 'Producto desconocido',
                                style: procesado || completado
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                              subtitle: Text(
                                subtitulo.isEmpty ? '—' : subtitulo,
                                style: procesado || completado
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(
                                      estadoLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: estadoColor.shade800,
                                      ),
                                    ),
                                    backgroundColor: estadoColor.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (!procesado && !widget.readOnly)
                                    noDisponible
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
                                        : IconButton(
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
                                          ),
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
                      ),
              ),
              // Botón Finalizar compra (activas) o Procesar (pendientes de procesar)
              if (tieneCompletados && !widget.readOnly)
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
                    child: FilledButton.icon(
                      onPressed: () {
                        if (widget.pendienteDeProcesar) {
                          _navegarAProcesarCompra(context, lista, shopping);
                        } else {
                          _finalizarCompra(context, lista);
                        }
                      },
                      icon: Icon(widget.pendienteDeProcesar ? LucideIcons.package : LucideIcons.checkCircle),
                      label: Text(widget.pendienteDeProcesar ? 'Procesar' : 'Finalizar compra'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Formatea una fecha en formato ISO (YYYY-MM-DD) a DD/MM/YYYY.
  String _formatearFechaString(String fechaIso) {
    final d = DateTime.tryParse(fechaIso);
    if (d == null) return fechaIso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
