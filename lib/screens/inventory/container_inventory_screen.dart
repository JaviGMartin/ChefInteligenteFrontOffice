import 'package:flutter/material.dart';

import '../../models/inventario.dart';
import '../../services/stock_service.dart';
import '../../widgets/main_layout.dart';

class ContainerInventoryScreen extends StatefulWidget {
  const ContainerInventoryScreen({
    super.key,
    required this.contenedorId,
    required this.contenedorNombre,
  });

  final int contenedorId;
  final String contenedorNombre;

  @override
  State<ContainerInventoryScreen> createState() =>
      _ContainerInventoryScreenState();
}

class _ContainerInventoryScreenState extends State<ContainerInventoryScreen> {
  late Future<List<Inventario>> _future;

  @override
  void initState() {
    super.initState();
    _future = StockService().fetchInventarios(contenedorId: widget.contenedorId);
  }

  static bool _isCaducado(String? fechaCaducidad) {
    if (fechaCaducidad == null || fechaCaducidad.isEmpty) return false;
    final d = DateTime.tryParse(fechaCaducidad);
    if (d == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dateOnly = DateTime(d.year, d.month, d.day);
    return dateOnly.isBefore(today);
  }

  static String _formatCaducidad(String? fechaCaducidad) {
    if (fechaCaducidad == null || fechaCaducidad.isEmpty) return '—';
    final d = DateTime.tryParse(fechaCaducidad);
    if (d == null) return fechaCaducidad;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _cantidadYUnidad(Inventario i) {
    final c = i.cantidad;
    final u = i.unidadMedida?.abreviatura ?? i.unidadMedida?.nombre ?? '';
    final cantidadStr = c == c.truncate() ? c.toInt().toString() : c.toString();
    return u.isNotEmpty ? '$cantidadStr $u' : cantidadStr;
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: widget.contenedorNombre,
      child: FutureBuilder<List<Inventario>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _future = StockService()
                              .fetchInventarios(contenedorId: widget.contenedorId);
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin productos en este contenedor',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inv = list[index];
              final nombre = inv.producto?.nombre ?? '—';
              final caducado = _isCaducado(inv.fechaCaducidad);
              final caducidadText = _formatCaducidad(inv.fechaCaducidad);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nombre,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caducidadText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: caducado
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: caducado ? FontWeight.w600 : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _cantidadYUnidad(inv),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
