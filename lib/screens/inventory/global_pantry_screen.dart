import 'package:flutter/material.dart';

import '../../models/contenedor.dart';
import '../../services/hogar_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/main_layout.dart';
import 'container_inventory_screen.dart';

class GlobalPantryScreen extends StatefulWidget {
  const GlobalPantryScreen({super.key});

  @override
  State<GlobalPantryScreen> createState() => _GlobalPantryScreenState();
}

class _GlobalPantryScreenState extends State<GlobalPantryScreen> {
  late Future<List<Contenedor>> _future;

  @override
  void initState() {
    super.initState();
    _future = StockService().fetchContenedores();
    hogarActivoIdNotifier.addListener(_onHogarActivoChanged);
  }

  @override
  void dispose() {
    hogarActivoIdNotifier.removeListener(_onHogarActivoChanged);
    super.dispose();
  }

  void _onHogarActivoChanged() {
    if (mounted) {
      setState(() => _future = StockService().fetchContenedores());
    }
  }

  static const Map<String, String> _tipoLabels = {
    'nevera': 'Nevera',
    'despensa': 'Despensa',
    'congelador': 'Congelador',
    'otro': 'Otro',
  };

  static IconData _iconForTipo(String? tipo) {
    switch (tipo) {
      case 'nevera':
        return Icons.kitchen;
      case 'congelador':
        return Icons.ac_unit;
      case 'despensa':
      case 'otro':
      default:
        return Icons.inventory_2;
    }
  }

  Future<void> _configurarBasicos() async {
    final hogarId = await HogarService().getHogarIdActual();
    if (hogarId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona un hogar primero en Mis Casas.'),
          ),
        );
      }
      return;
    }
    try {
      final stock = StockService();
      await stock.createContenedor(hogarId: hogarId, nombre: 'Nevera', tipo: 'nevera');
      await stock.createContenedor(hogarId: hogarId, nombre: 'Congelador', tipo: 'congelador');
      await stock.createContenedor(hogarId: hogarId, nombre: 'Despensa', tipo: 'despensa');
      if (mounted) {
        setState(() => _future = StockService().fetchContenedores());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contenedores básicos creados.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Despensa',
      child: FutureBuilder<List<Contenedor>>(
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
                          _future = StockService().fetchContenedores();
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
                      Icons.kitchen_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes contenedores',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configura Nevera, Congelador y Despensa para organizar tu inventario.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _configurarBasicos,
                      icon: const Icon(Icons.add_home_work, size: 20),
                      label: const Text('Configurar mis básicos'),
                    ),
                  ],
                ),
              ),
            );
          }

          final byHogar = <String, List<Contenedor>>{};
          for (final c in list) {
            final key = c.hogarNombre?.isNotEmpty == true
                ? c.hogarNombre!
                : 'Sin hogar';
            byHogar.putIfAbsent(key, () => []).add(c);
          }
          final hogarNames = byHogar.keys.toList()..sort();

          return ListView.builder(
            itemCount: hogarNames.length,
            itemBuilder: (context, index) {
              final hogarNombre = hogarNames[index];
              final contenedores = byHogar[hogarNombre]!;
              return ExpansionTile(
                leading: Icon(
                  Icons.home_work,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  hogarNombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${contenedores.length} contenedor${contenedores.length == 1 ? '' : 'es'}',
                ),
                children: contenedores
                    .map(
                      (c) => ListTile(
                        leading: Icon(
                          _iconForTipo(c.tipo),
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(c.nombre),
                        subtitle: Text(
                          _tipoLabels[c.tipo] ?? c.tipo ?? '—',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => ContainerInventoryScreen(
                                contenedorId: c.id,
                                contenedorNombre: c.nombre,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}
