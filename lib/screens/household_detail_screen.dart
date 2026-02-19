import 'package:flutter/material.dart';

import '../models/contenedor.dart';
import '../models/hogar.dart';
import '../models/inventario.dart';
import '../models/unidad_medida.dart';
import '../services/auth_service.dart';
import '../services/hogar_service.dart';
import '../services/stock_service.dart';
import '../widgets/app_drawer.dart';

class HouseholdDetailScreen extends StatefulWidget {
  final Hogar hogar;

  const HouseholdDetailScreen({
    super.key,
    required this.hogar,
  });

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nombreController;
  late TextEditingController _direccionController;
  late TextEditingController _telefonoController;
  late bool _isPrincipal;
  late Future<List<Contenedor>> _contenedoresFuture;
  late Future<List<Inventario>> _inventarioFuture;
  late TabController _tabController;
  String _search = '';
  bool _isSaving = false;
  bool _hasChanges = false;
  final Map<String, bool> _expandedSections = {};
  final Map<String, String> _contenedorTipos = const {
    'nevera': 'Nevera',
    'despensa': 'Despensa',
    'congelador': 'Congelador',
    'otro': 'Otro',
  };

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.hogar.nombre);
    _direccionController = TextEditingController(text: widget.hogar.direccion ?? '');
    _telefonoController = TextEditingController(text: widget.hogar.telefono ?? '');
    _isPrincipal = widget.hogar.esPrincipal;
    _contenedoresFuture = StockService().fetchContenedores(hogarId: widget.hogar.id);
    _inventarioFuture = StockService().fetchInventarios(hogarId: widget.hogar.id);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await HogarService().updateHogar(
        hogarId: widget.hogar.id,
        nombre: _nombreController.text.trim(),
        direccion: _direccionController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hogar actualizado')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _refreshContenedores() {
    setState(() {
      _contenedoresFuture = StockService().fetchContenedores(hogarId: widget.hogar.id);
    });
  }

  void _refreshInventario() {
    setState(() {
      _inventarioFuture = StockService().fetchInventarios(hogarId: widget.hogar.id);
    });
  }

  Future<void> _refreshHogar() async {
    try {
      final result = await HogarService().fetchHogares();
      final updated = result.hogares.where((h) => h.id == widget.hogar.id).toList();
      if (updated.isEmpty || !mounted) {
        return;
      }
      final hogar = updated.first;
      setState(() {
        _isPrincipal = hogar.esPrincipal;
      });
    } catch (_) {}
  }

  Future<void> _confirmDeleteHogar() async {
    final controller = TextEditingController();
    bool canDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Eliminar hogar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Escribe "${widget.hogar.nombre}" para confirmar.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    onChanged: (value) {
                      setState(() {
                        canDelete = value.trim() == widget.hogar.nombre;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: canDelete ? () => Navigator.of(dialogContext).pop(true) : null,
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        await HogarService().deleteHogar(widget.hogar.id);
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hogar eliminado')),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  Future<void> _openContenedorSheet(Contenedor contenedor) async {
    final nombreController = TextEditingController(text: contenedor.nombre);
    String tipo = contenedor.tipo ?? 'otro';

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Editar contenedor', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    items: _contenedorTipos.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          tipo = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await StockService().updateContenedor(
                            id: contenedor.id,
                            nombre: nombreController.text.trim(),
                            tipo: tipo,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contenedor actualizado')),
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Eliminar contenedor'),
                              content: const Text('¿Seguro que quieres eliminar este contenedor?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirm != true) {
                          return;
                        }
                        try {
                          await StockService().deleteContenedor(contenedor.id);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contenedor eliminado')),
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      child: const Text('Eliminar Contenedor'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );

    if (updated == true) {
      _refreshContenedores();
    }
  }

  Future<void> _openCreateContenedorSheet() async {
    final nombreController = TextEditingController();
    String tipo = 'nevera';

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nuevo contenedor', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    items: _contenedorTipos.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          tipo = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        if (nombre.isEmpty) {
                          return;
                        }
                        try {
                          await StockService().createContenedor(
                            hogarId: widget.hogar.id,
                            nombre: nombre,
                            tipo: tipo,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contenedor creado')),
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      child: const Text('Crear'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );

    if (created == true) {
      _refreshContenedores();
    }
  }

  Future<void> _openInventarioSheet(Inventario item) async {
    List<Contenedor> contenedores = [];
    List<UnidadMedida> unidades = [];
    try {
      contenedores = await StockService().fetchContenedores(hogarId: widget.hogar.id);
      unidades = await StockService().fetchUnidadesMedida();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
      return;
    }

    if (contenedores.isEmpty || unidades.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faltan datos para editar el inventario.')),
        );
      }
      return;
    }

    final cantidadController = TextEditingController(text: item.cantidad.toString());
    int contenedorId = contenedores.any((c) => c.id == item.contenedorId)
        ? item.contenedorId
        : contenedores.first.id;
    int unidadMedidaId = unidades.any((u) => u.id == item.unidadMedidaId)
        ? item.unidadMedidaId
        : unidades.first.id;
    DateTime? caducidad = item.fechaCaducidad != null ? DateTime.tryParse(item.fechaCaducidad!) : null;
    DateTime? apertura = item.fechaApertura != null ? DateTime.tryParse(item.fechaApertura!) : null;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Editar inventario', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Editando: ${item.producto?.nombre ?? 'Producto'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: unidadMedidaId,
                      items: unidades
                          .map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.nombre} (${u.abreviatura ?? ''})'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            unidadMedidaId = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Unidad de medida'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: contenedorId,
                      items: contenedores
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nombre),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            contenedorId = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Ubicación'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha de caducidad'),
                      subtitle: Text(caducidad?.toIso8601String().split('T').first ?? 'Sin fecha'),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: caducidad ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            caducidad = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha de apertura'),
                      subtitle: Text(apertura?.toIso8601String().split('T').first ?? 'Sin fecha'),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: apertura ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            apertura = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final cantidad = double.tryParse(cantidadController.text.trim()) ?? 0;
                          try {
                            await StockService().updateInventario(
                              id: item.id,
                              contenedorId: contenedorId,
                              unidadMedidaId: unidadMedidaId,
                              cantidad: cantidad,
                              fechaCaducidad: caducidad?.toIso8601String().split('T').first,
                              fechaApertura: apertura?.toIso8601String().split('T').first,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Inventario actualizado')),
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (updated == true) {
      _refreshInventario();
    }
  }

  Future<void> _togglePrincipal(bool value) async {
    if (!value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe existir un hogar principal')),
      );
      return;
    }

    try {
      await HogarService().setHogarPrincipal(widget.hogar.id);
      if (!mounted) {
        return;
      }
      await AuthService().fetchUser(forceRefresh: true);
      // No actualizar hogar activo: principal y activo están desacoplados. El drawer y listas se refrescan vía hogaresDataChangedNotifier.
      await _refreshHogar();
      _hasChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hogar principal actualizado correctamente')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Widget _buildConfiguracionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: 'Nombre del hogar'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _direccionController,
          decoration: const InputDecoration(labelText: 'Dirección'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefonoController,
          decoration: const InputDecoration(labelText: 'Teléfono'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Principal'),
          value: _isPrincipal,
          onChanged: _isSaving ? null : _togglePrincipal,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: const Text('Guardar cambios'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _confirmDeleteHogar,
            child: const Text('Eliminar Hogar'),
          ),
        ),
      ],
    );
  }

  Widget _buildContenedoresTab() {
    return FutureBuilder<List<Contenedor>>(
      future: _contenedoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final contenedores = snapshot.data ?? [];
        if (contenedores.isEmpty) {
          return const Center(child: Text('No hay contenedores.'));
        }
        return ListView.builder(
          itemCount: contenedores.length,
          itemBuilder: (context, index) {
            final c = contenedores[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(c.nombre),
                subtitle: Text(c.tipo ?? 'Tipo sin definir'),
                trailing: Text(c.ubicacion ?? ''),
                onTap: () => _openContenedorSheet(c),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInventarioTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar producto o contenedor',
            ),
            onChanged: (value) => setState(() {
              _search = value.trim().toLowerCase();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Inventario>>(
            future: _inventarioFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final items = snapshot.data ?? [];
              final filtered = _search.isEmpty
                  ? items
                  : items.where((item) {
                      final nombre = item.producto?.nombre.toLowerCase() ?? '';
                      final marca = item.producto?.marca?.toLowerCase() ?? '';
                      final contenedor = item.contenedor?.nombre.toLowerCase() ?? '';
                      return nombre.contains(_search) ||
                          marca.contains(_search) ||
                          contenedor.contains(_search);
                    }).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No hay resultados.'));
              }
              final Map<String, List<Inventario>> grouped = {};
              for (final item in filtered) {
                final key = (item.contenedor?.nombre ?? 'Sin contenedor').trim();
                grouped.putIfAbsent(key, () => []).add(item);
              }
              for (final entry in grouped.entries) {
                entry.value.sort((a, b) {
                  final da = _parseDate(a.fechaCaducidad);
                  final db = _parseDate(b.fechaCaducidad);
                  if (da == null && db == null) {
                    return 0;
                  }
                  if (da == null) {
                    return 1;
                  }
                  if (db == null) {
                    return -1;
                  }
                  return da.compareTo(db);
                });
              }
              final keys = grouped.keys.toList()..sort();
              return ListView(
                children: [
                  for (final key in keys)
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        key: PageStorageKey('inv-$key'),
                        initiallyExpanded: _expandedSections[key] ?? true,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedSections[key] = expanded;
                          });
                        },
                        backgroundColor: Colors.grey.shade50,
                        collapsedBackgroundColor: Colors.grey.shade100,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text(
                          '${key.toUpperCase()} (${grouped[key]!.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              children: grouped[key]!.map(_buildInventarioItem).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventarioItem(Inventario item) {
    final producto = item.producto?.nombre ?? 'Producto';
    final marca = item.producto?.marca ?? '';
    final unidad = item.unidadMedida?.abreviatura ?? '';
    final caduca = _parseDate(item.fechaCaducidad);
    final caducaText = caduca != null ? _formatDate(caduca) : 'Sin fecha';
    final caducaColor = _caducidadColor(caduca);
    return Dismissible(
      key: ValueKey('inv-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Eliminar del inventario'),
              content: const Text('¿Seguro que quieres eliminar este artículo?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
        return confirm == true;
      },
      onDismissed: (_) async {
        try {
          await StockService().deleteInventario(item.id);
          _refreshInventario();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.toString())),
            );
          }
          _refreshInventario();
        }
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Text(marca.isNotEmpty ? '$producto ($marca)' : producto),
          subtitle: Text(
            'Caduca: $caducaText',
            style: TextStyle(color: caducaColor),
          ),
          trailing: Text('${item.cantidad} $unidad'),
          onTap: () => _openInventarioSheet(item),
        ),
      ),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  Color _caducidadColor(DateTime? date) {
    if (date == null) {
      return Colors.black54;
    }
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    if (dateOnly.isBefore(nowOnly)) {
      return Colors.redAccent;
    }
    if (dateOnly.difference(nowOnly).inDays <= 3) {
      return Colors.orange;
    }
    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.hogar.nombre),
          leading: canPop ? BackButton(color: primary) : null,
          iconTheme: IconThemeData(color: primary),
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Configuración'),
              Tab(text: 'Contenedores'),
              Tab(text: 'Inventario'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildConfiguracionTab(),
            _buildContenedoresTab(),
            _buildInventarioTab(),
          ],
        ),
        floatingActionButton: _tabController.index == 1
            ? FloatingActionButton(
                backgroundColor: primary,
                onPressed: _openCreateContenedorSheet,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}
