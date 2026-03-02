import 'package:flutter/material.dart';

import '../models/lista_compra.dart';
import '../models/pendiente_compra.dart';
import '../services/shopping_service.dart';
import '../widgets/main_layout.dart';

/// Pantalla de Ingredientes a productos: ingredientes pendientes de asignar a una lista.
/// Swipe derecha = "Añadir rápido" a la lista por defecto. Tap = modal para elegir lista (y opcionalmente marca/supermercado).
class PurchaseFunnelScreen extends StatefulWidget {
  const PurchaseFunnelScreen({super.key});

  @override
  State<PurchaseFunnelScreen> createState() => _PurchaseFunnelScreenState();
}

class _PurchaseFunnelScreenState extends State<PurchaseFunnelScreen> {
  late Future<List<PendienteCompra>> _pendientesFuture;
  final ShoppingService _shopping = ShoppingService();

  @override
  void initState() {
    super.initState();
    _pendientesFuture = _shopping.getPendientes();
  }

  void _refresh() {
    setState(() {
      _pendientesFuture = _shopping.getPendientes();
    });
  }

  Future<void> _anadirRapido(BuildContext context, PendienteCompra p) async {
    try {
      await _shopping.distribuirPendiente(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${p.displayNombre}» añadido a la lista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
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

  Future<void> _abrirModalSeleccion(BuildContext context, PendienteCompra p) async {
    List<ListaCompraCabecera> listas;
    try {
      listas = await _shopping.getListas();
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
      return;
    }
    if (!mounted) return;
    final listaId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ModalSeleccionLista(
        pendiente: p,
        listas: listas,
      ),
    );
    if (listaId == null || !mounted) return;
    try {
      await _shopping.distribuirPendiente(p.id, listaDestinoId: listaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${p.displayNombre}» añadido a la lista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
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
    return MainLayout(
      title: 'Ingredientes a productos',
      child: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _pendientesFuture;
        },
        child: FutureBuilder<List<PendienteCompra>>(
          future: _pendientesFuture,
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
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay ingredientes en Ingredientes a productos',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Añade recetas a la semana desde Recetas; lo que falte en la despensa aparecerá aquí.',
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
                        Text(
                          'Añadir rápido',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    await _anadirRapido(context, p);
                    return false;
                  },
                  child: ListTile(
                    title: Text(
                      p.displayNombre,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(p.cantidadTexto),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                    onTap: () => _abrirModalSeleccion(context, p),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ModalSeleccionLista extends StatefulWidget {
  const _ModalSeleccionLista({
    required this.pendiente,
    required this.listas,
  });

  final PendienteCompra pendiente;
  final List<ListaCompraCabecera> listas;

  @override
  State<_ModalSeleccionLista> createState() => _ModalSeleccionListaState();
}

class _ModalSeleccionListaState extends State<_ModalSeleccionLista> {
  late List<ListaCompraCabecera> _listas;

  @override
  void initState() {
    super.initState();
    _listas = List<ListaCompraCabecera>.from(widget.listas);
  }

  Future<void> _crearLista() async {
    final tituloController = TextEditingController();
    final fechaController = TextEditingController();
    DateTime? fechaSeleccionada;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                            fechaController.text =
                                '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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

    if (result == true && tituloController.text.trim().isNotEmpty && mounted) {
      try {
        final fechaPrevista = fechaSeleccionada != null
            ? '${fechaSeleccionada!.year}-${fechaSeleccionada!.month.toString().padLeft(2, '0')}-${fechaSeleccionada!.day.toString().padLeft(2, '0')}'
            : null;
        final shopping = ShoppingService();
        await shopping.crearLista(tituloController.text.trim(), fechaPrevista: fechaPrevista);
        final nuevasListas = await shopping.getListas();
        setState(() {
          _listas = nuevasListas;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lista "${tituloController.text.trim()}" creada.'), behavior: SnackBarBehavior.floating),
          );
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

    tituloController.dispose();
    fechaController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = widget.pendiente;
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Añadir a lista',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${pendiente.displayNombre} · ${pendiente.cantidadTexto}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _listas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No tienes listas activas.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _crearLista,
                              icon: const Icon(Icons.add),
                              label: const Text('Crear lista'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _listas.length,
                        itemBuilder: (context, index) {
                          final lista = _listas[index];
                          return ListTile(
                            leading: Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                            title: Text(lista.titulo),
                            subtitle: Text('${lista.items.length} ítems'),
                            onTap: () => Navigator.of(context).pop(lista.id),
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
