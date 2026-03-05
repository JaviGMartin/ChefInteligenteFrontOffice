import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/hogar.dart';
import '../services/hogar_service.dart';
import '../services/shopping_service.dart';

/// Resultado del diálogo "Preferencia de supermercado" tras Añadir faltantes.
class AnadirFaltantesDialogResult {
  const AnadirFaltantesDialogResult({this.repartir = false, this.proveedorId, this.fechaPrevista})
      : assert(!repartir || (proveedorId == null && fechaPrevista == null));

  const AnadirFaltantesDialogResult.repartir() : this(repartir: true);
  factory AnadirFaltantesDialogResult.unaLista(int proveedorId, String? fechaPrevista) =>
      AnadirFaltantesDialogResult(repartir: false, proveedorId: proveedorId, fechaPrevista: fechaPrevista);

  final bool repartir;
  final int? proveedorId;
  final String? fechaPrevista;
}

/// Diálogo: Preferencia de supermercado. Dropdown proveedores, fecha opcional, Repartir / Usar como preferencia.
/// Reutilizado desde Cocina y desde Calendario (añadir ingredientes faltantes de la semana).
class AnadirFaltantesDialog extends StatefulWidget {
  const AnadirFaltantesDialog({
    super.key,
    required this.onRepartir,
    required this.onUnaLista,
    this.initialProveedorId,
  });

  final VoidCallback onRepartir;
  final void Function(int proveedorId, String? fechaPrevista) onUnaLista;
  final int? initialProveedorId;

  @override
  State<AnadirFaltantesDialog> createState() => _AnadirFaltantesDialogState();
}

class _AnadirFaltantesDialogState extends State<AnadirFaltantesDialog> {
  List<ProveedorItem> _proveedores = [];
  int? _ultimoProveedorId;
  bool _loading = true;
  String? _error;
  int? _selectedProveedorId;
  String? _fechaPrevista;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shopping = ShoppingService();
    final hogarService = HogarService();
    try {
      final results = await Future.wait([
        shopping.getProveedores(),
        hogarService.fetchHogares(),
      ]);
      final proveedores = results[0] as List<ProveedorItem>;
      final hogaresResult = results[1] as HogaresResult;
      Hogar? hogarActivo;
      for (final h in hogaresResult.hogares) {
        if (h.id == hogaresResult.hogarActivoId) {
          hogarActivo = h;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _proveedores = proveedores;
        _ultimoProveedorId = hogarActivo?.ultimoProveedorId;
        final sugerido = widget.initialProveedorId;
        _selectedProveedorId = sugerido != null && proveedores.any((p) => p.id == sugerido)
            ? sugerido
            : (_ultimoProveedorId != null && proveedores.any((p) => p.id == _ultimoProveedorId))
                ? _ultimoProveedorId
                : (proveedores.isNotEmpty ? proveedores.first.id : null);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Preferencia de supermercado', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              )
            else ...[
              if (_proveedores.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No hay supermercados configurados. Usa "Repartir en varias listas" para elegir listas manualmente.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<int>(
                    value: _selectedProveedorId,
                    decoration: const InputDecoration(labelText: 'Supermercado preferido'),
                    items: _proveedores.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.nombre))).toList(),
                    onChanged: (v) => setState(() => _selectedProveedorId = v),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextButton.icon(
                  icon: const Icon(LucideIcons.calendar),
                  label: Text(_fechaPrevista == null ? 'Añadir fecha prevista de compra (opcional)' : 'Fecha: $_fechaPrevista'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && mounted) {
                      final s = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      setState(() => _fechaPrevista = s);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onRepartir,
                        icon: const Icon(LucideIcons.listChecks, size: 18),
                        label: const Text('Repartir en varias listas'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _proveedores.isEmpty || _selectedProveedorId == null
                            ? null
                            : () => widget.onUnaLista(_selectedProveedorId!, _fechaPrevista),
                        icon: const Icon(LucideIcons.listPlus, size: 18),
                        label: const Text('Usar como preferencia'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
