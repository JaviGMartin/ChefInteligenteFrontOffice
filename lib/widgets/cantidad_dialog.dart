import 'package:flutter/material.dart';

import '../services/shopping_service.dart';

/// Diálogo para elegir formato (pack/unidad), unidad de medida y cantidad al añadir un producto.
/// Devuelve (cantidad, completado, productoProveedorId, unidadMedidaId) o null si cancela.
class CantidadDialog extends StatefulWidget {
  const CantidadDialog({
    super.key,
    required this.producto,
    this.formatos = const [],
    this.unidades = const [],
    this.initialCompletado = false,
    this.initialProductoProveedorId,
  });

  final ProductoSimple producto;
  final List<FormatoProveedor> formatos;
  final List<UnidadMedidaCompleta> unidades;
  /// Si true, el checkbox "Ya en el carro" viene marcado por defecto (útil al añadir por EAN).
  final bool initialCompletado;
  /// Si se proporciona (p. ej. desde EAN escaneado), preselecciona este formato en el desplegable.
  final int? initialProductoProveedorId;

  @override
  State<CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<CantidadDialog> {
  late final TextEditingController _controller;
  late bool _completado;
  FormatoProveedor? _formatoSeleccionado;
  UnidadMedidaCompleta? _unidadSeleccionada;

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
    if (tipo == null) tipo = 'volumen';
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
    _controller = TextEditingController(text: '1');
    _completado = widget.initialCompletado;
    if (widget.formatos.isNotEmpty) {
      if (widget.initialProductoProveedorId != null) {
        try {
          _formatoSeleccionado = widget.formatos.firstWhere(
            (f) => f.id == widget.initialProductoProveedorId,
          );
        } catch (_) {
          _formatoSeleccionado = widget.formatos.first;
        }
      } else {
        _formatoSeleccionado = widget.formatos.first;
      }
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
