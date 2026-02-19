import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shopping_service.dart';

/// Pantalla para elegir un producto y añadirlo a una lista de compra (Crear ítem).
class AddProductoToListaScreen extends StatefulWidget {
  const AddProductoToListaScreen({
    super.key,
    required this.listaId,
  });

  final int listaId;

  @override
  State<AddProductoToListaScreen> createState() => _AddProductoToListaScreenState();
}

class _AddProductoToListaScreenState extends State<AddProductoToListaScreen> {
  List<ProductoSimple>? _productos;
  List<ProductoSimple>? _filtered;
  String _query = '';
  Object? _error;
  bool _loading = true;

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
      final list = await context.read<ShoppingService>().getProductos();
      if (!mounted) return;
      setState(() {
        _productos = list;
        _filtered = _applyQuery(list, _query);
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

  List<ProductoSimple> _applyQuery(List<ProductoSimple> list, String q) {
    if (q.trim().isEmpty) return list;
    final lower = q.trim().toLowerCase();
    return list
        .where((p) =>
            p.nombre.toLowerCase().contains(lower) ||
            (p.marca?.toLowerCase().contains(lower) ?? false))
        .toList();
  }

  Future<void> _anadirProducto(ProductoSimple producto) async {
    List<FormatoProveedor> formatos = [];
    List<UnidadMedidaCompleta> unidades = [];
    try {
      final results = await Future.wait([
        context.read<ShoppingService>().getPreciosProveedores(producto.id),
        context.read<ShoppingService>().getUnidadesMedida(),
      ]);
      formatos = results[0] as List<FormatoProveedor>;
      unidades = results[1] as List<UnidadMedidaCompleta>;
    } catch (_) {
      // Si falla, mostramos el diálogo sin formatos y con unidades vacías (se usará fallback)
    }
    if (!mounted) return;

    final result = await showDialog<(double, bool, int?, int?)>(
      context: context,
      builder: (context) => _CantidadDialog(
        producto: producto,
        formatos: formatos,
        unidades: unidades,
      ),
    );
    if (result == null || !mounted) return;
    final (cantidad, completado, productoProveedorId, unidadMedidaId) = result;

    try {
      await context.read<ShoppingService>().addItemToLista(
            widget.listaId,
            producto.id,
            cantidad,
            unidadMedidaId: unidadMedidaId ?? producto.unidadMedidaId,
            productoProveedorId: productoProveedorId,
            completado: completado,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto añadido a la lista.'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear ítem'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nombre o marca',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (s) {
                setState(() {
                  _query = s;
                  _filtered = _productos != null ? _applyQuery(_productos!, _query) : null;
                });
              },
            ),
          ),
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
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

    final list = _filtered ?? [];
    if (list.isEmpty) {
      return Center(
        child: Text(
          _query.trim().isEmpty
              ? 'No hay productos.'
              : 'Sin resultados para "$_query".',
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        return ListTile(
          title: Text(p.nombre),
          subtitle: p.marca != null && p.marca!.isNotEmpty
              ? Text(p.marca!)
              : null,
          onTap: () => _anadirProducto(p),
        );
      },
    );
  }
}

class _CantidadDialog extends StatefulWidget {
  const _CantidadDialog({
    required this.producto,
    this.formatos = const [],
    this.unidades = const [],
  });

  final ProductoSimple producto;
  final List<FormatoProveedor> formatos;
  final List<UnidadMedidaCompleta> unidades;

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  final _controller = TextEditingController(text: '1');
  bool _completado = false;
  FormatoProveedor? _formatoSeleccionado;
  UnidadMedidaCompleta? _unidadSeleccionada;

  /// Unidades relevantes según el tipo del formato (volumen/peso) o del producto. Siempre incluye "Unidad" (packs).
  static List<UnidadMedidaCompleta> _unidadesRelevantes(
    List<UnidadMedidaCompleta> todas, {
    FormatoProveedor? formato,
    ProductoSimple? producto,
  }) {
    String? tipo;
    if (formato != null && (formato.unidadMedidaTipo == 'volumen' || formato.unidadMedidaTipo == 'peso')) {
      tipo = formato.unidadMedidaTipo;
    } else if (producto != null && producto.unidadMedidaId != null) {
      try {
        final u = todas.firstWhere((x) => x.id == producto.unidadMedidaId);
        if (u.tipo == 'volumen' || u.tipo == 'peso') tipo = u.tipo;
      } catch (_) {}
    }
    if (tipo == null) tipo = 'volumen'; // fallback para productos sin formato
    return todas
        .where((u) => u.tipo == 'unidad' || u.tipo == tipo)
        .toList();
  }

  List<UnidadMedidaCompleta> _getUnidadesRelevantes() => _unidadesRelevantes(
        widget.unidades,
        formato: _formatoSeleccionado,
        producto: widget.producto,
      );

  @override
  void initState() {
    super.initState();
    if (widget.formatos.isNotEmpty) {
      _formatoSeleccionado = widget.formatos.first;
    }
    final relevantes = _getUnidadesRelevantes();
    if (relevantes.isNotEmpty) {
      if (widget.formatos.isNotEmpty) {
        try {
          _unidadSeleccionada = relevantes.firstWhere((u) => u.tipo == 'unidad');
        } catch (_) {
          _unidadSeleccionada = relevantes.first;
        }
      } else {
        if (widget.producto.unidadMedidaId != null) {
          try {
            _unidadSeleccionada = relevantes.firstWhere((u) => u.id == widget.producto.unidadMedidaId);
          } catch (_) {
            _unidadSeleccionada = relevantes.first;
          }
        } else {
          _unidadSeleccionada = relevantes.first;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatos = widget.formatos;
    final mostrarFormato = formatos.isNotEmpty;
    final unidadesRelevantes = _getUnidadesRelevantes();
    final mostrarUnidadMedida = unidadesRelevantes.length > 1;
    final labelCantidad = _unidadSeleccionada != null
        ? 'Cantidad (${_unidadSeleccionada!.abreviatura ?? _unidadSeleccionada!.nombre})'
        : 'Cantidad (${widget.producto.unidadMedidaAbreviatura ?? 'ud.'})';

    return AlertDialog(
      title: Text(widget.producto.nombre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mostrarFormato) ...[
              DropdownButtonFormField<FormatoProveedor>(
                value: _formatoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Formato (pack / unidad)',
                  border: OutlineInputBorder(),
                ),
                items: formatos
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.label),
                        ))
                    .toList(),
                onChanged: (f) {
                  setState(() {
                    _formatoSeleccionado = f;
                    final nuevas = _getUnidadesRelevantes();
                    if (nuevas.isNotEmpty && _unidadSeleccionada != null) {
                      final estaEnLista = nuevas.any((u) => u.id == _unidadSeleccionada!.id);
                      if (!estaEnLista) {
                        try {
                          _unidadSeleccionada = nuevas.firstWhere((u) => u.tipo == 'unidad');
                        } catch (_) {
                          _unidadSeleccionada = nuevas.first;
                        }
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            if (mostrarUnidadMedida) ...[
              DropdownButtonFormField<UnidadMedidaCompleta>(
                value: _unidadSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Unidad de medida',
                  border: const OutlineInputBorder(),
                  helperText: _formatoSeleccionado?.unidadMedidaTipo == 'peso'
                      ? 'Elige Unidad (packs) o unidades de peso (kg, gr). Al procesar la compra se convierte.'
                      : 'Elige Unidad (packs) o unidades de volumen (L, ml). Al procesar la compra se convierte.',
                ),
                items: unidadesRelevantes
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text('${u.nombre}${u.abreviatura != null && u.abreviatura != u.nombre ? ' (${u.abreviatura})' : ''}'),
                        ))
                    .toList(),
                onChanged: (u) => setState(() => _unidadSeleccionada = u),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: labelCantidad,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: !mostrarFormato,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _completado,
              onChanged: (v) => setState(() => _completado = v ?? false),
              title: const Text('Ya en el carro'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(
                _controller.text.trim().replaceAll(',', '.'));
            if (v != null && v > 0) {
              final formatoId = _formatoSeleccionado?.id;
              final unidadId = _unidadSeleccionada?.id;
              Navigator.of(context).pop<(double, bool, int?, int?)>((
                v,
                _completado,
                formatoId,
                unidadId,
              ));
            }
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}
