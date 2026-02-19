import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/contenedor.dart';
import '../models/lista_compra.dart';
import '../services/shopping_service.dart';
import '../services/stock_service.dart';
import '../state/kitchen_state.dart';
import '../widgets/main_layout.dart';

/// Pantalla para asignar contenedor, cantidad y fecha de caducidad a cada ítem
/// completado de una lista antes de pasarlos al inventario.
class ProcesarCompraScreen extends StatefulWidget {
  const ProcesarCompraScreen({
    super.key,
    required this.listaId,
    required this.hogarId,
  });

  final int listaId;
  final int hogarId;

  @override
  State<ProcesarCompraScreen> createState() => _ProcesarCompraScreenState();
}

class _ProcesarCompraScreenState extends State<ProcesarCompraScreen> {
  List<ListaCompraItem>? _items;
  List<Contenedor>? _contenedores;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  /// Por cada ítem: contenedor seleccionado, cantidad y fecha de caducidad.
  final Map<int, int> _contenedorPorItem = {};
  final Map<int, double> _cantidadPorItem = {};
  final Map<int, DateTime?> _fechaPorItem = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shopping = context.read<ShoppingService>();
      // Incluir listas activas Y pendientes de procesar (la lista puede venir de "Pend. procesar").
      final activas = await shopping.getListas(archivada: false);
      final pendientes = await shopping.getListas(archivada: false, pendienteProcesar: true);
      final listas = [...activas, ...pendientes];
      ListaCompraCabecera? lista;
      try {
        lista = listas.firstWhere((l) => l.id == widget.listaId);
      } catch (_) {
        lista = null;
      }
      if (lista == null) {
        setState(() {
          _error = Exception('Lista no encontrada');
          _loading = false;
        });
        return;
      }
      final completados = lista.items
          .where((i) =>
              (i.estado == 'completado' || i.completado == true) &&
              i.estado != 'procesado')
          .toList();

      final contenedores =
          await StockService().fetchContenedores(hogarId: widget.hogarId);

      if (!mounted) return;
      setState(() {
        _items = completados;
        _contenedores = contenedores;
        for (final item in completados) {
          _contenedorPorItem[item.id] =
              item.contenedorId ?? contenedores.first.id;
          _cantidadPorItem[item.id] =
              item.cantidadCompra > 0 ? item.cantidadCompra : item.cantidad;
          _fechaPorItem[item.id] = DateTime.now().add(const Duration(days: 7));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  static String _fechaToIso(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _procesar() async {
    final items = _items;
    final contenedores = _contenedores;
    if (items == null || items.isEmpty || contenedores == null) return;

    setState(() => _sending = true);
    try {
      final lineas = items.map((item) {
        final contenedorId = _contenedorPorItem[item.id] ?? contenedores.first.id;
        final cantidad = _cantidadPorItem[item.id] ?? item.cantidad;
        final fecha = _fechaPorItem[item.id];
        return ProcesarCompraLinea(
          listaCompraItemId: item.id,
          contenedorId: contenedorId,
          cantidad: cantidad,
          unidadMedidaId: item.unidadMedidaId,
          fechaCaducidad: fecha != null ? _fechaToIso(fecha) : null,
        );
      }).toList();

      final result =
          await context.read<ShoppingService>().procesarCompra(lineas);

      if (!mounted) return;
      context.read<KitchenState>().refreshAfterPurchase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Procesar compra',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error.toString().replaceFirst('Exception: ', '')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _items ?? [];
    final contenedores = _contenedores ?? [];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay ítems completados para procesar. Marca productos en el carro en la lista.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (contenedores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crea al menos un contenedor en Despensa para poder añadir al inventario.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ItemRow(
                item: item,
                contenedores: contenedores,
                contenedorId: _contenedorPorItem[item.id] ?? contenedores.first.id,
                cantidad: _cantidadPorItem[item.id] ?? item.cantidad,
                fechaCaducidad: _fechaPorItem[item.id],
                onContenedorChanged: (id) {
                  setState(() => _contenedorPorItem[item.id] = id);
                },
                onCantidadChanged: (v) {
                  setState(() => _cantidadPorItem[item.id] = v);
                },
                onFechaChanged: (d) {
                  setState(() => _fechaPorItem[item.id] = d);
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _sending
                  ? null
                  : () async {
                      await _procesar();
                    },
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.packageCheck),
              label: Text(_sending ? 'Procesando…' : 'Añadir al inventario'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.contenedores,
    required this.contenedorId,
    required this.cantidad,
    required this.fechaCaducidad,
    required this.onContenedorChanged,
    required this.onCantidadChanged,
    required this.onFechaChanged,
  });

  final ListaCompraItem item;
  final List<Contenedor> contenedores;
  final int contenedorId;
  final double cantidad;
  final DateTime? fechaCaducidad;
  final ValueChanged<int> onContenedorChanged;
  final ValueChanged<double> onCantidadChanged;
  final ValueChanged<DateTime?> onFechaChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.producto?.nombre ?? 'Producto',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Cantidad prevista: ${item.cantidad} ${item.unidadMedida?.abreviatura ?? ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: contenedorId,
              decoration: const InputDecoration(
                labelText: 'Contenedor',
                isDense: true,
              ),
              items: contenedores
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onContenedorChanged(v);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: cantidad.toString(),
              decoration: InputDecoration(
                labelText: 'Cantidad (${item.unidadMedida?.abreviatura ?? 'ud.'})',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (s) {
                final v = double.tryParse(s.replaceAll(',', '.'));
                if (v != null && v > 0) onCantidadChanged(v);
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: fechaCaducidad ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) onFechaChanged(picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de caducidad',
                  isDense: true,
                ),
                child: Text(
                  fechaCaducidad != null
                      ? '${fechaCaducidad!.day.toString().padLeft(2, '0')}/${fechaCaducidad!.month.toString().padLeft(2, '0')}/${fechaCaducidad!.year}'
                      : 'Elegir fecha',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
