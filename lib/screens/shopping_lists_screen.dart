import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../models/lista_compra.dart';
import '../services/shopping_service.dart';
import '../widgets/main_layout.dart';
import 'single_shopping_list_screen.dart';

/// Pantalla de listas de compra: Activas (incluye pendientes de procesar) e Historial (archivadas).
/// Una lista sigue en Activas cuando pasa a «pendiente de procesar»; en su detalle se muestran los botones Procesar / Volver a activas / Archivar.
class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key, this.initialListaId});

  final int? initialListaId;

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen>
    with TickerProviderStateMixin {
  late TabController _sectionTabController;
  Future<List<ListaCompraCabecera>>? _listasFuture;
  Future<List<ListaCompraCabecera>>? _listasArchivadasFuture;

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _sectionTabController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final svc = context.read<ShoppingService>();
    setState(() {
      _listasFuture = _cargarListasActivas(svc);
      _listasArchivadasFuture = svc.getListas(archivada: true);
    });
  }

  /// Activas + pendientes de procesar unidos (todas las listas no archivadas).
  Future<List<ListaCompraCabecera>> _cargarListasActivas(ShoppingService svc) async {
    final results = await Future.wait([
      svc.getListas(),
      svc.getListas(archivada: false, pendienteProcesar: true),
    ]);
    final activas = results[0];
    final pendientes = results[1];
    final idsPendientes = pendientes.map((l) => l.id).toSet();
    final soloActivas = activas.where((l) => !idsPendientes.contains(l.id)).toList();
    return [...soloActivas, ...pendientes];
  }

  Future<void> _archivarLista(
    BuildContext context,
    ListaCompraCabecera lista,
    ShoppingService shoppingService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar lista'),
        content: Text(
          lista.titulo.isEmpty
              ? '¿Archivar esta lista? Saldrá del listado activo.'
              : '¿Archivar "${lista.titulo}"? Saldrá del listado activo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await shoppingService.archivarLista(lista.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lista archivada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
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

  Future<void> _eliminarListaArchivada(
    BuildContext context,
    ListaCompraCabecera lista,
    ShoppingService shoppingService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text(
          lista.titulo.isEmpty
              ? '¿Eliminar definitivamente esta lista? Esta acción no se puede deshacer.'
              : '¿Eliminar definitivamente "${lista.titulo}"? Esta acción no se puede deshacer.',
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
    if (confirm != true || !context.mounted) return;
    try {
      await shoppingService.eliminarLista(lista.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lista eliminada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
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
    _listasFuture ??= _cargarListasActivas(shoppingService);
    _listasArchivadasFuture ??= shoppingService.getListas(archivada: true);

    return MainLayout(
      title: 'Compra',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _sectionTabController,
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Activas'),
              Tab(text: 'Historial'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _sectionTabController,
              children: [
                _buildActivasContent(shoppingService),
                _buildHistorialContent(shoppingService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivasContent(ShoppingService shoppingService) {
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: _listasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brandGreen),
          );
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
                    'Añade productos desde Plan (Ingredientes a productos) o crea una lista al usar «Añadir faltantes» en una receta.',
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
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: listas.length,
          itemBuilder: (context, index) {
            final lista = listas[index];
            final titulo = lista.titulo.isEmpty ? 'Lista ${lista.id}' : lista.titulo;
            final numItems = lista.items.length;
            final subtitle = numItems > 0
                ? '$numItems ${numItems == 1 ? 'producto' : 'productos'}'
                : (lista.fechaPrevista ?? '');
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(LucideIcons.listChecks, color: AppColors.brandGreen),
                title: Text(titulo),
                subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.moreVertical),
                      tooltip: 'Opciones',
                      onSelected: (value) {
                        if (value == 'archivar') {
                          _archivarLista(context, lista, shoppingService);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'archivar',
                          child: Row(
                            children: [
                              Icon(LucideIcons.archive, size: 20),
                              SizedBox(width: 8),
                              Text('Archivar lista'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SingleShoppingListScreen(
                        listaId: lista.id,
                        pendienteDeProcesar: lista.pendienteProcesar,
                      ),
                    ),
                  ).then((_) => _refresh());
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistorialContent(ShoppingService shoppingService) {
    return FutureBuilder<List<ListaCompraCabecera>>(
      future: _listasArchivadasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brandGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                    LucideIcons.archive,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay listas archivadas',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: listas.length,
          itemBuilder: (context, index) {
            final lista = listas[index];
            final titulo = lista.titulo.isEmpty ? 'Lista ${lista.id}' : lista.titulo;
            final fecha = lista.fechaProcesado ?? lista.fechaPrevista ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(LucideIcons.listChecks, color: AppColors.brandBlue),
                title: Text(titulo),
                subtitle: fecha.isNotEmpty ? Text(fecha) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.moreVertical),
                      tooltip: 'Opciones',
                      onSelected: (value) {
                        if (value == 'eliminar') {
                          _eliminarListaArchivada(context, lista, shoppingService);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(LucideIcons.trash2, size: 20),
                              SizedBox(width: 8),
                              Text('Eliminar lista'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SingleShoppingListScreen(
                        listaId: lista.id,
                        readOnly: true,
                      ),
                    ),
                  ).then((_) => _refresh());
                },
              ),
            );
          },
        );
      },
    );
  }
}
